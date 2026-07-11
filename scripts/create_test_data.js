#!/usr/bin/env node

const https = require('https');

// Parse args
const args = process.argv.slice(2);
const getArg = (name) => {
    const idx = args.indexOf(name);
    return idx !== -1 ? args[idx + 1] : null;
};

const env = getArg('--env') || 'dev';
const emailPrefix = getArg('--email') || `test_cli_${Math.floor(Math.random() * 10000)}`;
const dealsCount = parseInt(getArg('--deals')) || 3;

if (env !== 'dev' && env !== 'prod') {
    console.error('❌ Hata: --env parametresi sadece "dev" veya "prod" olabilir.');
    process.exit(1);
}

// Configs
const configs = {
    dev: {
        apiKey: 'AIzaSyDOmrSDBA_tzCCrPdDk28uMSXwpkDw_EZU',
        projectId: 'sicak-firsatlar-e6eae'
    },
    prod: {
        apiKey: 'AIzaSyAELCy_sPjPKIg204FLnPFInx7xLh5dFUA',
        projectId: 'firsatkolik-prod-e6eae'
    }
};

const config = configs[env];
const email = `${emailPrefix}@test.firsatkolik.com`;
const password = 'password123';
const username = `CLI_${emailPrefix}`;

console.log(`🧪 Test Verisi Jeneratörü (CLI)`);
console.log(`----------------------------------------`);
console.log(`Ortam:   ${env.toUpperCase()}`);
console.log(`Proje:   ${config.projectId}`);
console.log(`E-posta: ${email}`);
console.log(`Şifre:   ${password}`);
console.log(`Adet:    ${dealsCount} mock fırsat`);
console.log(`----------------------------------------\n`);

// Helper for https requests
function request(url, method, headers, body) {
    return new Promise((resolve, reject) => {
        const u = new URL(url);
        const options = {
            hostname: u.hostname,
            path: u.pathname + u.search,
            method: method,
            headers: {
                'Content-Type': 'application/json',
                ...headers
            }
        };

        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    if (res.statusCode >= 400) {
                        reject(new Error(`HTTP ${res.statusCode}: ${parsed.error ? parsed.error.message : data}`));
                    } else {
                        resolve(parsed);
                    }
                } catch (e) {
                    reject(new Error(`HTTP ${res.statusCode}: Response parse hatası - ${data}`));
                }
            });
        });

        req.on('error', (err) => reject(err));
        if (body) {
            req.write(JSON.stringify(body));
        }
        req.end();
    });
}

async function main() {
    try {
        // 1. Auth Sign Up
        console.log('🔄 1. Kullanıcı Auth kaydı oluşturuluyor...');
        const authUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${config.apiKey}`;
        const authRes = await request(authUrl, 'POST', {}, {
            email,
            password,
            returnSecureToken: true
        });

        const idToken = authRes.idToken;
        const uid = authRes.localId;
        console.log(`✅ Auth kaydı başarılı! UID: ${uid}`);

        const authHeaders = {
            'Authorization': `Bearer ${idToken}`
        };

        // 2. Create users/{uid} document
        console.log('🔄 2. Firestore profil belgesi (users/{uid}) yazılıyor...');
        const userUrl = `https://firestore.googleapis.com/v1/projects/${config.projectId}/databases/(default)/documents/users/${uid}`;
        const userFields = {
            fields: {
                uid: { stringValue: uid },
                username: { stringValue: username },
                nickname: { stringValue: `${username}_nick` },
                email: { stringValue: email },
                points: { integerValue: '120' },
                dealCount: { integerValue: String(dealsCount) },
                totalLikes: { integerValue: '15' },
                createdAt: { timestampValue: new Date().toISOString() },
                followedCategories: { arrayValue: { values: [{ stringValue: 'elektronik' }, { stringValue: 'supermarket' }] } },
                watchKeywords: { arrayValue: { values: [{ stringValue: 'xiaomi' }, { stringValue: 'iphone' }] } }
            }
        };
        await request(userUrl, 'PATCH', authHeaders, userFields);
        console.log(`✅ Profil belgesi yazıldı.`);

        // 3. Create notificationPreferences/main document
        console.log('🔄 3. Bildirim tercihleri yazılıyor...');
        const prefsUrl = `https://firestore.googleapis.com/v1/projects/${config.projectId}/databases/(default)/documents/users/${uid}/notificationPreferences/main`;
        const prefsFields = {
            fields: {
                pushMasterEnabled: { booleanValue: true },
                dealNotificationsEnabled: { booleanValue: true },
                communityNotificationsEnabled: { booleanValue: true },
                submissionStatusNotificationsEnabled: { booleanValue: true },
                marketingNotificationsEnabled: { booleanValue: false },
                quietHoursEnabled: { booleanValue: false },
                quietHoursStart: { stringValue: '23:00' },
                quietHoursEnd: { stringValue: '08:00' },
                timezone: { stringValue: 'Europe/Istanbul' },
                schemaVersion: { integerValue: '1' }
            }
        };
        await request(prefsUrl, 'PATCH', authHeaders, prefsFields);
        console.log(`✅ Bildirim tercihleri yazıldı.`);

        // 4. Create userDevices document
        console.log('🔄 4. Cihaz kaydı yazılıyor...');
        const deviceUrl = `https://firestore.googleapis.com/v1/projects/${config.projectId}/databases/(default)/documents/userDevices/test_device_${uid}`;
        const deviceFields = {
            fields: {
                uid: { stringValue: uid },
                deviceId: { stringValue: `test_device_${uid}` },
                platform: { stringValue: 'android' },
                fcmToken: { stringValue: `test_token_${uid}` },
                permissionStatus: { stringValue: 'authorized' },
                active: { booleanValue: true },
                lastSeenAt: { timestampValue: new Date().toISOString() }
            }
        };
        await request(deviceUrl, 'PATCH', authHeaders, deviceFields);
        console.log(`✅ Cihaz kaydı yazıldı.`);

        // 5. Create mock deals
        console.log(`🔄 5. ${dealsCount} adet mock fırsat oluşturuluyor...`);
        const dealsUrl = `https://firestore.googleapis.com/v1/projects/${config.projectId}/databases/(default)/documents/deals`;

        for (let i = 1; i <= dealsCount; i++) {
            const price = Math.floor(Math.random() * 4000) + 1000;
            const originalPrice = Math.round(price * 1.25);
            const discountRate = Math.round(((originalPrice - price) / originalPrice) * 100);

            const dealFields = {
                fields: {
                    title: { stringValue: `Test CLI Fırsatı ${i} - Xiaomi Redmi Note 13` },
                    description: { stringValue: `Bu bir test fırsatıdır. CLI aracıyla oluşturulmuştur.` },
                    price: { doubleValue: price },
                    originalPrice: { doubleValue: originalPrice },
                    discountRate: { integerValue: String(discountRate) },
                    store: { stringValue: 'Amazon' },
                    category: { stringValue: 'elektronik' },
                    subCategory: { stringValue: 'Telefon & Aksesuarları' },
                    url: { stringValue: `https://www.amazon.com.tr/dp/test_cli_${uid}_${i}` },
                    link: { stringValue: `https://www.amazon.com.tr/dp/test_cli_${uid}_${i}` },
                    imageUrl: { stringValue: 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500' },
                    imageUrls: { arrayValue: { values: [{ stringValue: 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500' }] } },
                    hotVotes: { integerValue: '0' },
                    coldVotes: { integerValue: '0' },
                    expiredVotes: { integerValue: '0' },
                    commentCount: { integerValue: '0' },
                    postedBy: { stringValue: uid },
                    createdAt: { timestampValue: new Date().toISOString() },
                    isApproved: { booleanValue: false },
                    isRejected: { booleanValue: false },
                    isExpired: { booleanValue: false },
                    isUserSubmitted: { booleanValue: true },
                    isEditorPick: { booleanValue: false },
                    shipping: { stringValue: 'free' },
                    couponCode: { stringValue: `CLIKOD${i}` }
                }
            };

            await request(dealsUrl, 'POST', authHeaders, dealFields);
            console.log(`   🔸 Mock fırsat ${i} oluşturuldu.`);
        }

        console.log(`\n🎉 BAŞARIYLA TAMAMLANDI!`);
        console.log(`----------------------------------------`);
        console.log(`Kullanıcı UID:   ${uid}`);
        console.log(`Kullanıcı Giriş: email: "${email}", password: "${password}"`);
        console.log(`Fırsatlar ve kullanıcı profil verileri Firestore'da başarıyla oluşturuldu.`);
        console.log(`Admin paneline gidip test kullanıcısını ve fırsatlarını görebilir, testleri gerçekleştirebilirsiniz.`);
        console.log(`----------------------------------------`);

    } catch (error) {
        console.error(`\n❌ İşlem sırasında hata oluştu:`, error.message);
        process.exit(1);
    }
}

main();
