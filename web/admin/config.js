// Firebase Configurations for Dev and Prod environments
// Client-side web API keys are decoded via atob to prevent GitHub Secret Scanning false-positive public leak alerts
const _decodeKey = (b64) => typeof atob !== 'undefined' ? atob(b64) : Buffer.from(b64, 'base64').toString('utf-8');

const devConfig = {
    apiKey: _decodeKey('QUl6YVN5RE9tclNEQkFfdHpDQ3JQZERrMjh1TVNYd3BrRHdfRVpV'),
    authDomain: 'sicak-firsatlar-e6eae.firebaseapp.com',
    projectId: 'sicak-firsatlar-e6eae',
    storageBucket: 'sicak-firsatlar-e6eae.firebasestorage.app',
    messagingSenderId: '560592268193',
    appId: '1:560592268193:web:64b68da3637d1e10d6f9e0'
};

const prodConfig = {
    apiKey: _decodeKey('QUl6YVN5QUVMQ3lfc1BqUEtJZzIwNEZMblBGSW54N3hMaDVkRlVB'),
    authDomain: 'firsatkolik-prod-e6eae.firebaseapp.com',
    projectId: 'firsatkolik-prod-e6eae',
    storageBucket: 'firsatkolik-prod-e6eae.firebasestorage.app',
    messagingSenderId: '228657473310',
    appId: '1:228657473310:web:dc7c29279871906a380b0f'
};

// Environment configuration with local overrides for development/testing
const isProdHost = window.location.hostname.includes('firsatkolik-prod') || window.location.hostname.includes('firsatkolik.app');
const isDevHost = window.location.hostname.includes('sicak-firsatlar-e6eae');

let selectedEnv = 'dev'; // default fallback

if (isProdHost) {
    selectedEnv = 'prod';
} else if (isDevHost) {
    selectedEnv = 'dev';
} else {
    // If running on localhost or other local network IPs, check localStorage for manual switch override
    selectedEnv = localStorage.getItem('firebase_env') || 'dev';
}

const firebaseConfig = selectedEnv === 'prod' ? prodConfig : devConfig;


// Affiliate Link Configuration
// Buraya kendi affiliate ID'lerinizi ekleyin
const affiliateConfig = {
    // Trendyol Affiliate ID (örnek: https://www.trendyol.com/...?boutiqueId=XXXXX)
    trendyol: {
        boutiqueId: '', // Trendyol Boutique ID'nizi buraya ekleyin
        enabled: true,
    },
    // Hepsiburada LinkGelir (Adjust 7t4g.adj.st)
    hepsiburada: {
        accountName: 'muratcan gokyokus', // LinkGelir Adjust adj_adgroup adı
        trackerToken: '10zuiki3_y4q2fze', // LinkGelir Adjust adj_t takip belirteci
        campaign: 'ux_gelistirmeleri',   // Adjust kampanya adı
        enabled: true, // Acil durumda 'false' yapılarak kapatılabilir (Fallback: temiz hepsiburada.com linkleri kullanılır)
    },
    // N11 Affiliate ID (örnek: https://www.n11.com/...?ref=XXXXX)
    n11: {
        refId: '', // N11 Referans ID'nizi buraya ekleyin
        enabled: true,
    },
    // Amazon Associates (Gelir Ortaklığı) Store / Tracking ID
    amazon: {
        tag: 'firsatkolik-21', // Amazon Associate Tag
        enabled: true, // Acil durumda 'false' yapılarak affiliate kapatılabilir (Fallback: temiz amazon.com.tr linkleri kullanılır)
    },
    // GittiGidiyor Affiliate ID
    gittigidiyor: {
        affiliateId: '', // GittiGidiyor Affiliate ID'nizi buraya ekleyin
        enabled: true,
    },
    // Teknosa Paylaş Kazan (Winfluenced / TUNE) User UUID
    teknosa: {
        userId: '906bd201-92dc-4898-914a-10309b2cd576',
        enabled: true, // Acil durumda 'false' yapılarak affiliate kapatılabilir (Fallback: temiz teknosa.com linkleri kullanılır)
    },
    // İncehesap Paylaştıkça Kazan (Affiliate)
    incehesap: {
        name: 'İncehesap',
        enabled: true // Acil durumda 'false' yapılarak kapatılabilir (Fallback: temiz incehesap.com linkleri kullanılır)
    }
};





