const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Türkçe karakter temizleme fonksiyonu
const cleanTopicName = (str) => {
    if (!str) return 'genel';
    return str.toLowerCase()
        .replace(/ğ/g, 'g')
        .replace(/ü/g, 'u')
        .replace(/ş/g, 's')
        .replace(/ı/g, 'i')
        .replace(/ö/g, 'o')
        .replace(/ç/g, 'c')
        .replace(/[^a-z0-9_]/g, '_');
};

/**
 * 1. YENİ FIRSAT GELDİĞİNDE (Sadece Admin'e Bildir)
 * Firestore: deals/{dealId} -> onCreate
 */
exports.onDealCreated = functions.firestore
    .document('deals/{dealId}')
    .onCreate(async (snap, context) => {
        const deal = snap.data();
        const dealId = context.params.dealId;

        console.log('📢 Yeni fırsat eklendi (Admin bildirimi):', dealId, deal.title);

        // Eğer fırsat zaten onaylı geldiyse (örn: Admin panelinden eklendiyse)
        if (deal.isApproved === true) {
            console.log('✅ Fırsat onaylı olarak eklendi, kullanıcılara bildirim gönderiliyor...');
            return sendUserNotifications(deal, dealId);
        }

        // Onaysız fırsat -> Sadece Admin'e bildirim
        const payload = {
            notification: {
                title: "👮‍♂️ Yeni Onay Bekleyen Fırsat",
                body: `${deal.title}\n💰 ${deal.price} TL`,
            },
            data: {
                type: 'admin_deal',
                dealId: dealId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'admin_channel',
                    sound: 'default'
                }
            }
        };

        // Sadece 'admin_deals' topic'ine gönder
        // (Admin kullanıcıları bu topic'e abone olmalı)
        try {
            await admin.messaging().send({
                ...payload,
                topic: 'admin_deals'
            });
            console.log('✅ Admin bildirimi gönderildi');
        } catch (error) {
            console.error('❌ Admin bildirimi hatası:', error);
        }
    });

/**
 * 2. FIRSAT GÜNCELLENDİĞİNDE (Onaylandıysa Herkese Bildir)
 * Firestore: deals/{dealId} -> onUpdate
 */
exports.onDealUpdated = functions.firestore
    .document('deals/{dealId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();
        const dealId = context.params.dealId;

        // Sadece onay durumu false -> true olduğunda çalış
        if (oldData.isApproved === false && newData.isApproved === true) {
            console.log('🎉 Fırsat onaylandı! Kullanıcılara bildirim gönderiliyor:', dealId);
            return sendUserNotifications(newData, dealId);
        }

        return null;
    });

/**
 * Kullanıcılara bildirim gönderen yardımcı fonksiyon
 */
async function sendUserNotifications(deal, dealId) {
    const title = "🔥 Yeni Sıcak Fırsat!";
    const body = `${deal.title}\n💰 ${deal.price} TL`;
    const imageUrl = deal.imageUrl || null;

    const payload = {
        notification: {
            title: title,
            body: body,
        },
        data: {
            type: 'deal',
            dealId: dealId,
            category: deal.category || 'genel',
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
        android: {
            priority: 'high',
            notification: {
                channelId: 'deals_channel',
                sound: 'default',
                imageUrl: imageUrl
            }
        },
        apns: {
            payload: {
                aps: {
                    sound: 'default',
                    badge: 1,
                    mutableContent: 1
                }
            },
            fcm_options: {
                image: imageUrl
            }
        }
    };

    // Gönderilecek Topic'ler
    const topics = ['all_deals']; // Herkese gönder

    // Kategori Topic'i
    if (deal.category) {
        topics.push(`category_${cleanTopicName(deal.category)}`);
    }

    // Bildirimleri Gönder
    const promises = topics.map(topic => {
        return admin.messaging().send({
            ...payload,
            topic: topic
        }).then(() => console.log(`✅ Bildirim gönderildi (${topic})`))
          .catch(e => console.error(`❌ Hata (${topic}):`, e));
    });

    await Promise.all(promises);
}
