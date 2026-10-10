#!/usr/bin/env node

/**
 * FırsatKolik Test Kullanıcısı Oluşturma ve Senkronizasyon Aracı
 * E-posta: test@firsatkolik.app
 * Şifre:   Test12345!
 * Rol:     Normal Kullanıcı (isAdmin: false)
 */

const https = require('https');

// Ortam konfigürasyonları
const configs = {
    dev: {
        name: 'DEV (sicak-firsatlar-e6eae)',
        projectId: 'sicak-firsatlar-e6eae',
        apiKey: 'AIzaSyDOmrSDBA_tzCCrPdDk28uMSXwpkDw_EZU'
    },
    prod: {
        name: 'PROD (firsatkolik-prod-e6eae)',
        projectId: 'firsatkolik-prod-e6eae',
        apiKey: 'AIzaSyC3lE2ktKnMO21KP1EMh2S173wjrSauiio'
    }
};

const TEST_EMAIL = 'test@firsatkolik.app';
const TEST_PASSWORD = 'Test12345!';
const TEST_USERNAME = 'test_kullanici';
const TEST_DISPLAY_NAME = 'Test Kullanıcı Hesabı';

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
                let parsed;
                try {
                    parsed = JSON.parse(data);
                } catch (e) {
                    parsed = data;
                }
                resolve({ status: res.statusCode, data: parsed });
            });
        });

        req.on('error', reject);
        if (body) {
            req.write(typeof body === 'string' ? body : JSON.stringify(body));
        }
        req.end();
    });
}

async function setupTestUserForEnv(envKey) {
    const cfg = configs[envKey];
    console.log(`\n======================================================`);
    console.log(`🚀 [${cfg.name}] Test Kullanıcısı Kurulumu Başlatılıyor`);
    console.log(`======================================================`);

    let idToken = null;
    let uid = null;

    // 1. Adım: Firebase Auth hesabı oluşturmayı dene
    console.log(`1️⃣ Firebase Auth: Hesap oluşturuluyor (${TEST_EMAIL})...`);
    const signUpRes = await request(
        `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${cfg.apiKey}`,
        'POST',
        {},
        {
            email: TEST_EMAIL,
            password: TEST_PASSWORD,
            returnSecureToken: true
        }
    );

    if (signUpRes.status === 200) {
        console.log(`   ✅ Firebase Auth hesabı başarıyla OLUŞTURULDU.`);
        idToken = signUpRes.data.idToken;
        uid = signUpRes.data.localId;
    } else if (signUpRes.data && signUpRes.data.error && signUpRes.data.error.message.includes('EMAIL_EXISTS')) {
        console.log(`   ℹ️ Kullanıcı zaten mevcut. Mevcut hesaba giriş yapılıyor...`);
        const signInRes = await request(
            `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${cfg.apiKey}`,
            'POST',
            {},
            {
                email: TEST_EMAIL,
                password: TEST_PASSWORD,
                returnSecureToken: true
            }
        );

        if (signInRes.status === 200) {
            console.log(`   ✅ Giriş başarılı.`);
            idToken = signInRes.data.idToken;
            uid = signInRes.data.localId;
        } else {
            console.log(`   ⚠️ Şifre uyuşmadı, şifre sıfırlama / güncelleme deneniyor...`);
            console.log(`   Hata detayı:`, JSON.stringify(signInRes.data));
            return false;
        }
    } else {
        console.error(`   ❌ Auth oluşturma hatası:`, JSON.stringify(signUpRes.data));
        return false;
    }

    console.log(`   🔑 UID: ${uid}`);

    // 2. Adım: Firebase Auth profilini güncelle (DisplayName)
    console.log(`2️⃣ Firebase Auth: DisplayName güncelleniyor (${TEST_DISPLAY_NAME})...`);
    const updateAuthRes = await request(
        `https://identitytoolkit.googleapis.com/v1/accounts:update?key=${cfg.apiKey}`,
        'POST',
        {},
        {
            idToken: idToken,
            displayName: TEST_DISPLAY_NAME,
            returnSecureToken: true
        }
    );

    if (updateAuthRes.status === 200) {
        console.log(`   ✅ Auth displayName güncellendi.`);
        idToken = updateAuthRes.data.idToken || idToken;
    } else {
        console.log(`   ⚠️ Auth profile güncelleme uyarısı:`, updateAuthRes.data);
    }

    // 3. Adım: Firestore users/{uid} profil belgesini oluştur / güncelle
    console.log(`3️⃣ Cloud Firestore: users/${uid} profil kaydı oluşturuluyor...`);
    const nowIso = new Date().toISOString();

    const firestorePayload = {
        fields: {
            uid: { stringValue: uid },
            username: { stringValue: TEST_USERNAME },
            displayName: { stringValue: TEST_DISPLAY_NAME },
            email: { stringValue: TEST_EMAIL },
            profileImageUrl: { stringValue: 'assets/images/avatars/avatar_1.webp' },
            badges: { arrayValue: { values: [] } },
            points: { integerValue: '0' },
            dealCount: { integerValue: '0' },
            totalLikes: { integerValue: '0' },
            following: { arrayValue: { values: [] } },
            blockedUsers: { arrayValue: { values: [] } },
            isAdmin: { booleanValue: false },
            isadmin: { booleanValue: false },
            isCommentBanned: { booleanValue: false },
            isDealShareBanned: { booleanValue: false },
            createdAt: { timestampValue: nowIso },
            updatedAt: { timestampValue: nowIso }
        }
    };

    const firestoreUrl = `https://firestore.googleapis.com/v1/projects/${cfg.projectId}/databases/(default)/documents/users/${uid}`;
    const firestoreRes = await request(
        firestoreUrl,
        'PATCH',
        { 'Authorization': `Bearer ${idToken}` },
        firestorePayload
    );

    if (firestoreRes.status === 200) {
        console.log(`   ✅ Firestore users/${uid} belgesi başarıyla yazıldı.`);
    } else {
        console.error(`   ❌ Firestore yazma hatası (HTTP ${firestoreRes.status}):`, JSON.stringify(firestoreRes.data));
        return false;
    }

    // 4. Adım: Doğrulama Sorgusu (Firestore GET)
    console.log(`4️⃣ Doğrulama: Kayıt Firestore'dan tekrar okunuyor...`);
    const verifyRes = await request(
        firestoreUrl,
        'GET',
        { 'Authorization': `Bearer ${idToken}` },
        null
    );

    if (verifyRes.status === 200) {
        const fields = verifyRes.data.fields;
        console.log(`   ✅ DOĞRULAMA BAŞARILI!`);
        console.log(`      • E-posta:     ${fields.email?.stringValue}`);
        console.log(`      • Kullanıcı:   ${fields.username?.stringValue}`);
        console.log(`      • İsim:        ${fields.displayName?.stringValue}`);
        console.log(`      • Admin Yetki: ${fields.isAdmin?.booleanValue} (Normal Kullanıcı)`);
        console.log(`      • Avatar:      ${fields.profileImageUrl?.stringValue}`);
        console.log(`      • Puan / Deal: ${fields.points?.integerValue} Puan, ${fields.dealCount?.integerValue} Fırsat`);
    } else {
        console.warn(`   ⚠️ Doğrulama okuma uyarısı: HTTP ${verifyRes.status}`);
    }

    return true;
}

async function main() {
    console.log('🏁 FırsatKolik Test Hesabı Kurulumu');
    console.log(`Hedef E-posta: ${TEST_EMAIL}`);
    console.log(`Hedef Şifre:   ${TEST_PASSWORD}`);
    console.log(`Rol:           Normal Kullanıcı (Uygulamayı sıradan bir kullanıcı gibi kullanacak)`);

    // Sırasıyla DEV ve PROD ortamlarında oluştur
    const devOk = await setupTestUserForEnv('dev');
    const prodOk = await setupTestUserForEnv('prod');

    console.log(`\n======================================================`);
    console.log(`📊 KURULUM SONUCU:`);
    console.log(`   DEV Ortamı:  ${devOk ? '✅ BAŞARILI' : '❌ HATA'}`);
    console.log(`   PROD Ortamı: ${prodOk ? '✅ BAŞARILI' : '❌ HATA'}`);
    console.log(`======================================================\n`);
}

main().catch(err => {
    console.error('Beklenmeyen hata:', err);
    process.exit(1);
});
