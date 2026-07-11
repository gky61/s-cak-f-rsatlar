import subprocess
import json
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta

def get_access_token():
    result = subprocess.run(['gcloud', 'auth', 'print-access-token'], capture_output=True, text=True, shell=True)
    if result.returncode != 0:
        raise Exception("Failed to get gcloud token: " + result.stderr)
    lines = result.stdout.strip().split('\n')
    # Filter out warnings or python messages, token is usually a long string starting with ya29.
    for line in reversed(lines):
        clean_line = line.strip()
        if clean_line.startswith("ya29."):
            return clean_line
    return lines[-1].strip()

def parse_firestore_val(field):
    if not field:
        return None
    if 'booleanValue' in field:
        return field['booleanValue']
    if 'stringValue' in field:
        return field['stringValue']
    if 'integerValue' in field:
        return int(field['integerValue'])
    if 'arrayValue' in field:
        arr = field['arrayValue'].get('values', [])
        return [parse_firestore_val(v) for v in arr]
    if 'timestampValue' in field:
        ts_str = field['timestampValue']
        try:
            if ts_str.endswith('Z'):
                ts_str = ts_str[:-1] + '+00:00'
            if '.' in ts_str:
                parts = ts_str.split('.')
                time_part = parts[0]
                tz_part = parts[1]
                tz_start = -1
                for i, c in enumerate(tz_part):
                    if c in ('+', '-'):
                        tz_start = i
                        break
                if tz_start != -1:
                    frac = tz_part[:tz_start][:6]
                    tz = tz_part[tz_start:]
                    ts_str = f"{time_part}.{frac}{tz}"
                else:
                    ts_str = f"{time_part}.{tz_part[:6]}+00:00"
            return datetime.fromisoformat(ts_str)
        except Exception as e:
            return None
    return None

def get_date_val(fields, key):
    if key in fields:
        return parse_firestore_val(fields[key])
    return None

def get_bool_val(fields, key, default=False):
    if key in fields:
        val = parse_firestore_val(fields[key])
        if val is not None:
            return val
    return default

def get_string_val(fields, key, default=''):
    if key in fields:
        val = parse_firestore_val(fields[key])
        if val is not None:
            return val
    return default

def analyze_project(project_id, access_token):
    print(f"\n========================================\nAnalyzing Project: {project_id}\n========================================")
    
    # 1. Fetch Deals
    url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents:runQuery"
    query = {
        "structuredQuery": {
            "from": [{"collectionId": "deals"}]
        }
    }
    
    req = urllib.request.Request(
        url,
        data=json.dumps(query).encode('utf-8'),
        headers={
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json'
        },
        method='POST'
    )
    
    deals = []
    try:
        with urllib.request.urlopen(req) as response:
            res_data = response.read().decode('utf-8')
            results = json.loads(res_data)
            for res in results:
                if 'document' in res:
                    doc = res['document']
                    fields = doc.get('fields', {})
                    deals.append(fields)
    except Exception as e:
        print(f"Error fetching deals for {project_id}: {e}")
        return

    # 2. Fetch Users
    query_users = {
        "structuredQuery": {
            "from": [{"collectionId": "users"}]
        }
    }
    req_users = urllib.request.Request(
        url,
        data=json.dumps(query_users).encode('utf-8'),
        headers={
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json'
        },
        method='POST'
    )
    
    users = []
    try:
        with urllib.request.urlopen(req_users) as response:
            res_data = response.read().decode('utf-8')
            results = json.loads(res_data)
            for res in results:
                if 'document' in res:
                    doc = res['document']
                    fields = doc.get('fields', {})
                    users.append(fields)
    except Exception as e:
        print(f"Error fetching users for {project_id}: {e}")

    # 3. Fetch Telegram Bot Status
    bot_doc_url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/settings/telegramBot"
    req_bot = urllib.request.Request(
        bot_doc_url,
        headers={'Authorization': f'Bearer {access_token}'},
        method='GET'
    )
    bot_data = None
    try:
        with urllib.request.urlopen(req_bot) as response:
            bot_data = json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        if e.code != 404:
            print(f"Error fetching bot doc for {project_id}: {e}")
    except Exception as e:
        print(f"Error fetching bot doc for {project_id}: {e}")

    # 3.1 Fetch settings/app
    app_doc_url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/settings/app"
    req_app = urllib.request.Request(
        app_doc_url,
        headers={'Authorization': f'Bearer {access_token}'},
        method='GET'
    )
    app_data = None
    try:
        with urllib.request.urlopen(req_app) as response:
            app_data = json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        if e.code != 404:
            print(f"Error fetching settings/app for {project_id}: {e}")
    except Exception as e:
        print(f"Error fetching settings/app for {project_id}: {e}")

    # 3.2 Fetch systemConfig/notifications
    sys_config_url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/systemConfig/notifications"
    req_sys = urllib.request.Request(
        sys_config_url,
        headers={'Authorization': f'Bearer {access_token}'},
        method='GET'
    )
    sys_config_data = None
    try:
        with urllib.request.urlopen(req_sys) as response:
            sys_config_data = json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        if e.code != 404:
            print(f"Error fetching systemConfig/notifications for {project_id}: {e}")
    except Exception as e:
        print(f"Error fetching systemConfig/notifications for {project_id}: {e}")

    # Process Stats
    # A. Home Page Stats (Pending, Active, Bot, User)
    # Filter pending: isApproved == False && isRejected != True && isExpired != True
    # Filter active: isApproved == True
    # Bot: isUserSubmitted != True
    # User: isUserSubmitted == True
    
    pending_deals = []
    approved_deals = []
    bot_deals = []
    user_deals = []
    
    for d in deals:
        is_approved = get_bool_val(d, 'isApproved', False)
        is_rejected = get_bool_val(d, 'isRejected', False)
        is_expired = get_bool_val(d, 'isExpired', False)
        is_user_submitted = get_bool_val(d, 'isUserSubmitted', False)
        
        if not is_approved and not is_rejected and not is_expired:
            pending_deals.append(d)
        if is_approved:
            approved_deals.append(d)
            
        if is_user_submitted:
            user_deals.append(d)
        else:
            bot_deals.append(d)
            
    print(f"TOTAL DEALS IN DB: {len(deals)}")
    print(f"--- Home Page Tab Stats ---")
    print(f"Onay Bekleyen (Pending): {len(pending_deals)}")
    print(f"Toplam Aktif (Approved): {len(approved_deals)}")
    print(f"Bot Tarafından (Bot): {len(bot_deals)}")
    print(f"Kullanıcı Tarafından (User): {len(user_deals)}")
    
    # B. Dashboard Stats (Today Midnight TR timezone +3)
    # Today midnight local time (+3 UTC)
    tr_tz = timezone(timedelta(hours=3))
    now_tr = datetime.now(tr_tz)
    today_midnight_tr = now_tr.replace(hour=0, minute=0, second=0, microsecond=0)
    
    total_users_count = len(users)
    today_new_users_count = 0
    for u in users:
        created_at = get_date_val(u, 'createdAt')
        if created_at:
            # Convert created_at to TR time to check
            created_at_tr = created_at.astimezone(tr_tz)
            if created_at_tr >= today_midnight_tr:
                today_new_users_count += 1
                
    # Today's deals
    today_deals_count = 0
    today_approved_count = 0
    today_rejected_count = 0
    
    approval_times = []
    
    for d in deals:
        created_at = get_date_val(d, 'createdAt') or get_date_val(d, 'timestamp')
        is_approved = get_bool_val(d, 'isApproved', False)
        is_rejected = get_bool_val(d, 'isRejected', False)
        approved_at = get_date_val(d, 'approvedAt') or get_date_val(d, 'updatedAt')
        updated_at = get_date_val(d, 'updatedAt')
        
        if created_at:
            created_at_tr = created_at.astimezone(tr_tz)
            if created_at_tr >= today_midnight_tr:
                today_deals_count += 1
                
        if is_approved and approved_at:
            approved_at_tr = approved_at.astimezone(tr_tz)
            if approved_at_tr >= today_midnight_tr:
                today_approved_count += 1
                if created_at:
                    diff = approved_at - created_at
                    diff_ms = diff.total_seconds() * 1000
                    if diff_ms >= 0:
                        approval_times.append(diff_ms)
                        
        if not is_approved and is_rejected and updated_at:
            updated_at_tr = updated_at.astimezone(tr_tz)
            if updated_at_tr >= today_midnight_tr:
                today_rejected_count += 1
                
    avg_approval_time_str = '-'
    if approval_times:
        avg_ms = sum(approval_times) / len(approval_times)
        avg_minutes = round(avg_ms / 60000)
        if avg_minutes < 60:
            avg_approval_time_str = f"{avg_minutes} dk"
        else:
            avg_hours = avg_minutes // 60
            rem_minutes = avg_minutes % 60
            avg_approval_time_str = f"{avg_hours} sa {rem_minutes} dk"
            
    # Telegram Bot Status
    active_bot_count = 0
    if bot_data:
        bot_fields = bot_data.get('fields', {})
        last_hb = get_date_val(bot_fields, 'lastHeartbeatAt')
        status = get_string_val(bot_fields, 'status', '')
        if last_hb and status == 'online':
            # Check within 15 minutes in utc
            now_utc = datetime.now(timezone.utc)
            # Make last_hb timezone aware in case it's not
            if last_hb.tzinfo is None:
                last_hb = last_hb.replace(tzinfo=timezone.utc)
            diff_sec = abs((now_utc - last_hb).total_seconds())
            if diff_sec <= 15 * 60:
                active_bot_count = 1
                
    # Fetch and parse settings
    app_fields = app_data.get('fields', {}) if app_data else {}
    deal_sharing_enabled = get_bool_val(app_fields, 'dealSharingEnabled', True)
    comment_sharing_enabled = get_bool_val(app_fields, 'commentSharingEnabled', True)
    
    bot_fields = bot_data.get('fields', {}) if bot_data else {}
    bot_enabled = get_bool_val(bot_fields, 'botEnabled', True)
    
    sys_fields = sys_config_data.get('fields', {}) if sys_config_data else {}
    cat_hourly_limit = get_bool_val(sys_fields, 'categoryHourlyLimit', 3) # actually it's integer, get_bool_val works if we use parse_firestore_val
    # wait, get_bool_val uses parse_firestore_val which returns int if it's integer. So we can just use a helper
    def get_int_val(fields, key, default=0):
        if key in fields:
            val = parse_firestore_val(fields[key])
            if val is not None:
                return val
        return default
        
    cat_hourly_limit = get_int_val(sys_fields, 'categoryHourlyLimit', 3)
    cat_daily_limit = get_int_val(sys_fields, 'categoryDailyLimit', 8)

    print(f"--- Emergency Controls ---")
    print(f"settings/app -> dealSharingEnabled: {deal_sharing_enabled}")
    print(f"settings/app -> commentSharingEnabled: {comment_sharing_enabled}")
    print(f"settings/telegramBot -> botEnabled: {bot_enabled}")
    print(f"--- Bot & Notifications Settings ---")
    print(f"systemConfig/notifications -> categoryHourlyLimit: {cat_hourly_limit}")
    print(f"systemConfig/notifications -> categoryDailyLimit: {cat_daily_limit}")
    
    print(f"--- Dashboard Stats ---")
    print(f"Toplam Üye: {total_users_count}")
    print(f"Bugün Yeni Üye: {today_new_users_count}")
    print(f"Bugün Gelen Fırsat: {today_deals_count}")
    print(f"Onay Bekleyen (from query): {len(pending_deals)}")
    print(f"Bugün Onaylanan: {today_approved_count}")
    print(f"Bugün Reddedilen: {today_rejected_count}")
    print(f"Ortalama Onay Süresi: {avg_approval_time_str}")
    print(f"Aktif Telegram Bot: {active_bot_count}")

def main():
    access_token = get_access_token()
    analyze_project('sicak-firsatlar-e6eae', access_token)
    analyze_project('firsatkolik-prod-e6eae', access_token)

if __name__ == '__main__':
    main()
