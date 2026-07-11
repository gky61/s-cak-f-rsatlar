#!/usr/bin/env node

const https = require('https');

// Parse args
const args = process.argv.slice(2);
const getArg = (name) => {
    const idx = args.indexOf(name);
    return idx !== -1 ? args[idx + 1] : null;
};

const env = getArg('--env') || 'dev';
const emailPrefix = getArg('--email') || '';

if (!emailPrefix) {
    console.error('❌ Hata: --email parametresi (prefix veya tam e-posta) gereklidir.');
    process.exit(1);
}

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
const email = emailPrefix.includes('@') ? emailPrefix : `${emailPrefix}@test.firsatkolik.com`;
const password = 'password123';

console.log(`🧪 Test Kullanıcısı Silme ve Temizleme Aracı (CLI)`);
console.log(`----------------------------------------`);
console.log(`Ortam:   ${env.toUpperCase()}`);
console.log(`Proje:   ${config.projectId}`);
console.log(`E-posta: ${email}`);
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
        // 1. Auth Sign In to obtain ID Token
        console.log('🔄 1. Kullanıcı girişi yapılıyor...');
        const signInUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${config.apiKey}`;
        const signInRes = await request(signInUrl, 'POST', {}, {
            email,
            password,
            returnSecureToken: true
        });

        const idToken = signInRes.idToken;
        const uid = signInRes.localId;
        console.log(`   🔸 Giriş başarılı. UID: ${uid}`);

        // 2. Auth Delete Account
        console.log('🔄 2. Kullanıcı Auth hesabı siliniyor...');
        const deleteUrl = `https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${config.apiKey}`;
        await request(deleteUrl, 'POST', {}, {
            idToken
        });
        console.log(`✅ Auth hesabı başarıyla silindi!`);

        console.log(`\n🎉 BAŞARIYLA TAMAMLANDI!`);
        console.log(`----------------------------------------`);
        console.log(`Auth hesabı silindiğinden dolayı 'onUserDeleted' Firestore tetikleyicisi`);
        console.log(`arka planda çalışarak kullanıcıya ait tüm Firestore verilerini (profil,`);
        console.log(`fırsatlar, abonelikler, cihazlar) kalıcı olarak silecektir.`);
        console.log(`----------------------------------------`);

    } catch (error) {
        console.error(`\n❌ Hata oluştu:`, error.message);
        process.exit(1);
    }
}

main();
