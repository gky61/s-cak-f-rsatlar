#!/usr/bin/env python3
"""
FırsatKolik — Google AdMob MCP (Model Context Protocol) Server
---------------------------------------------------------------
Bu sunucu, Antigravity AI ve agent'ların AdMob gelirlerini, birim kimliklerini,
Android & iOS Dev/Prod sağlık durumlarını ve ROAS verilerini sorgulamasını sağlayan
resmi Model Context Protocol (MCP) stdio sunucusudur.

Desteklenen MCP Araçları (Tools):
  1. admob_get_status: Sistem sağlık ve platform durumunu sorgular.
  2. admob_get_report: Günlük eCPM, gösterim, tıklama ve gelir raporu üretir.
  3. admob_inspect_configs: Proje dosyalarını statik denetler (build.gradle, Info.plist, vb.).
  4. admob_list_units: Tüm reklam birimlerinin tam envanterini listeler.
  5. admob_verify_policy: AdMob politika ve UI/UX güvenlik kurallarını denetler.
  6. admob_calculate_net_profit: Pazarlama harcaması ile AdMob ve affiliate net kârlılığını hesaplar.
"""

import sys
import os
import json

# CLI fonksiyonlarını import et
sys.path.insert(0, os.path.dirname(__file__))
import admob_cli

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

TOOLS = [
    {
        "name": "admob_get_status",
        "description": "Android ve iOS (Dev/Prod) AdMob platform sağlık durumunu, aktif formatları ve Kill-Switch bilgisini döner.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "platform": {"type": "string", "enum": ["all", "android", "ios"], "default": "all", "description": "Platform filtresi"},
                "env": {"type": "string", "enum": ["all", "dev", "prod"], "default": "all", "description": "Ortam filtresi"}
            }
        }
    },
    {
        "name": "admob_get_report",
        "description": "Belirtilen gün sayısı ve platform/ortam için gösterim, tıklama, CTR, fill rate, eCPM ve tahmini AdMob gelir raporunu üretir.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "days": {"type": "integer", "default": 7, "description": "Kaç günlük rapor istendiği"},
                "platform": {"type": "string", "enum": ["all", "android", "ios"], "default": "all"},
                "env": {"type": "string", "enum": ["all", "dev", "prod"], "default": "all"},
                "format": {"type": "string", "enum": ["all", "native", "rewarded"], "default": "all"}
            }
        }
    },
    {
        "name": "admob_inspect_configs",
        "description": "Mobil kod tabanını (build.gradle, AndroidManifest.xml, Info.plist, firebase_options.dart) statik olarak denetler ve AdMob kimlik doğruluğunu raporlar.",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "admob_list_units",
        "description": "Android ve iOS için tanımlı tüm Native, Rewarded ve arşiv Banner reklam birim kimliklerini listeler.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "platform": {"type": "string", "enum": ["all", "android", "ios"], "default": "all"},
                "env": {"type": "string", "enum": ["all", "dev", "prod"], "default": "all"}
            }
        }
    },
    {
        "name": "admob_verify_policy",
        "description": "Uygulama arayüz bileşenlerinde FittedBox küçültme ihlali ve telemetri eksikliği olup olmadığını denetler.",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "admob_calculate_net_profit",
        "description": "Pazarlama reklam harcaması (CPI/CAC) ile AdMob ve Affiliate gelirlerini karşılaştırarak net kârlılık ve ROI analiz eder.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "ad_spend": {"type": "number", "description": "Google/Meta Ads reklam harcaması (TL)"},
                "admob_rev": {"type": "number", "description": "AdMob toplam geliri (TL)"},
                "affiliate_rev": {"type": "number", "default": 0.0, "description": "Affiliate geliri (TL)"}
            },
            "required": ["ad_spend", "admob_rev"]
        }
    }
]

def handle_call_tool(name, arguments):
    args = arguments or {}
    if name == "admob_get_status":
        return admob_cli.get_status(args.get("platform", "all"), args.get("env", "all"))
    elif name == "admob_get_report":
        return admob_cli.generate_report(
            args.get("days", 7),
            args.get("platform", "all"),
            args.get("env", "all"),
            args.get("format", "all")
        )
    elif name == "admob_inspect_configs":
        return admob_cli.inspect_codebase()
    elif name == "admob_list_units":
        return admob_cli.get_units(args.get("platform", "all"), args.get("env", "all"))
    elif name == "admob_verify_policy":
        return admob_cli.policy_check()
    elif name == "admob_calculate_net_profit":
        return admob_cli.calculate_net_profit(
            args.get("ad_spend", 0.0),
            args.get("admob_rev", 0.0),
            args.get("affiliate_rev", 0.0)
        )
    else:
        raise ValueError(f"Bilinmeyen araç: {name}")

def main():
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break
            line = line.strip()
            if not line:
                continue
            
            request = json.loads(line)
            req_id = request.get("id")
            method = request.get("method")
            
            if method == "initialize":
                response = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {
                            "tools": {}
                        },
                        "serverInfo": {
                            "name": "admob-orchestrator",
                            "version": "1.0.0"
                        }
                    }
                }
            elif method == "notifications/initialized":
                continue
            elif method == "tools/list":
                response = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "tools": TOOLS
                    }
                }
            elif method == "tools/call":
                params = request.get("params", {})
                tool_name = params.get("name")
                tool_args = params.get("arguments", {})
                try:
                    result_data = handle_call_tool(tool_name, tool_args)
                    response = {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "result": {
                            "content": [
                                {
                                    "type": "text",
                                    "text": json.dumps(result_data, indent=2, ensure_ascii=False)
                                }
                            ]
                        }
                    }
                except Exception as e:
                    response = {
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "error": {
                            "code": -32603,
                            "message": str(e)
                        }
                    }
            elif method == "ping":
                response = {"jsonrpc": "2.0", "id": req_id, "result": {}}
            else:
                response = {
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "error": {
                        "code": -32601,
                        "message": f"Method '{method}' not found"
                    }
                }
                
            sys.stdout.write(json.dumps(response, ensure_ascii=False) + "\n")
            sys.stdout.flush()
        except Exception as err:
            err_resp = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {
                    "code": -32700,
                    "message": f"Parse error: {str(err)}"
                }
            }
            sys.stdout.write(json.dumps(err_resp) + "\n")
            sys.stdout.flush()

if __name__ == "__main__":
    main()
