const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

// Türkçe karakter temizleme fonksiyonu
const normalize = (text = '') =>
  text
    .toLowerCase()
    .replace(/ç/g, 'c')
    .replace(/ğ/g, 'g')
    .replace(/ı/g, 'i')
    .replace(/ö/g, 'o')
    .replace(/ş/g, 's')
    .replace(/ü/g, 'u');

const cleanTopicName = (str) => {
  if (!str) return 'genel';
  return normalize(str).replace(/[^a-z0-9_]/g, '_');
};

// Eşleşen anahtar kelimeyi döndürür (ilk eşleşme)
const findMatchedKeyword = (text, keywords) => {
  const normalizedText = normalize(text);
  for (const kw of keywords) {
    if (!kw) continue;
    const k = normalize(String(kw));
    if (k && normalizedText.includes(k)) return kw;
  }
  return '';
};

// Anahtar kelime bildirimleri gönder - TÜM KULLANICILARA
// Genel bildirimler kapalı olsa bile, anahtar kelime varsa bildirim gider
// Kim paylaşırsa paylaşsın herkes alır
async function sendKeywordNotifications(dealId, title, description) {
  functions.logger.info('🔍 Anahtar kelime kontrolü başlıyor:', title);
  
  // TÜM kullanıcıları al (fcmToken olanlar)
  const snapshot = await admin
    .firestore()
    .collection('users')
    .get();

  if (snapshot.empty) {
    functions.logger.info('Hiç kullanıcı yok');
    return;
  }

  const text = `${title} ${description}`;
  const messages = [];
  let checkedUsers = 0;
  let matchedUsers = 0;

  snapshot.forEach((doc) => {
    const data = doc.data() || {};
    const token = data.fcmToken;
    
    if (!token) return;
    
    // Hem watchKeywords hem notificationKeywords alanlarını kontrol et
    let keywords = [];
    if (Array.isArray(data.watchKeywords) && data.watchKeywords.length > 0) {
      keywords = [...keywords, ...data.watchKeywords];
    }
    if (Array.isArray(data.notificationKeywords) && data.notificationKeywords.length > 0) {
      keywords = [...keywords, ...data.notificationKeywords];
    }
    
    // Duplicate'ları kaldır
    keywords = [...new Set(keywords)];
    
    if (keywords.length === 0) return;
    
    checkedUsers++;
    
    const matched = findMatchedKeyword(text, keywords);
    if (!matched) return;
    
    matchedUsers++;
    functions.logger.info(`✅ Eşleşme bulundu: ${doc.id} -> "${matched}"`);

    messages.push({
      token,
      notification: {
        title: '🎯 İlginizi Çeken Bir Fırsat Bulundu!',
        body: `"${matched}" kelimesi içeren yeni bir fırsat paylaşıldı. Hemen inceleyin!`,
      },
      data: {
        dealId,
        type: 'keyword',
        keyword: matched,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'keyword_alerts_channel',
          color: '#FF9800',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            'thread-id': 'keyword_alerts_channel',
            'interruption-level': 'time-sensitive',
            'relevance-score': 1.0,
          },
        },
      },
    });
  });

  functions.logger.info(`📊 Kontrol edilen: ${checkedUsers}, Eşleşen: ${matchedUsers}`);

  if (messages.length === 0) {
    functions.logger.info('Hiç eşleşme yok');
    return;
  }

  // FCM sendEach: 500 limit
  const batches = [];
  const size = 300;
  for (let i = 0; i < messages.length; i += size) {
    batches.push(messages.slice(i, i + size));
  }

  for (const batch of batches) {
    try {
      const resp = await admin.messaging().sendEach(batch);
      functions.logger.info('✅ Bildirim gönderildi', {
        success: resp.successCount,
        failure: resp.failureCount,
      });
    } catch (error) {
      functions.logger.error('❌ Bildirim hatası:', error);
    }
  }
}

// Genel kullanıcı bildirimleri gönder (topic bazlı)
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
    }).then(() => functions.logger.info(`Bildirim gönderildi (${topic})`))
      .catch(e => functions.logger.error(`Hata (${topic}):`, e));
  });

  await Promise.all(promises);
}

// Takip bildirimleri gönder - SADECE kullanıcı tarafından paylaşılan deal'ler için
async function sendFollowNotifications(deal, dealId) {
  functions.logger.info('🔍 sendFollowNotifications çağrıldı:', { dealId, isUserSubmitted: deal.isUserSubmitted, postedBy: deal.postedBy });
  
  // Sadece kullanıcı tarafından paylaşılan deal'ler için
  if (!deal.isUserSubmitted || !deal.postedBy) {
    functions.logger.info('❌ Takip bildirimi gönderilmeyecek (bot deal veya postedBy yok)', {
      isUserSubmitted: deal.isUserSubmitted,
      postedBy: deal.postedBy
    });
    return;
  }

  const followingUserId = deal.postedBy;
  
  try {
    // Takip edilen kullanıcının bilgilerini al
    const followingDoc = await admin.firestore().collection('users').doc(followingUserId).get();
    
    if (!followingDoc.exists) {
      functions.logger.warn('❌ Takip edilen kullanıcı bulunamadı:', followingUserId);
      return;
    }

    const followingData = followingDoc.data();
    const username = followingData?.username || 'Kullanıcı';
    const followersWithNotifications = followingData?.followersWithNotifications || [];

    functions.logger.info('📋 Takip edilen kullanıcı bilgileri:', {
      userId: followingUserId,
      username: username,
      followersWithNotificationsCount: Array.isArray(followersWithNotifications) ? followersWithNotifications.length : 0,
      followersWithNotifications: followersWithNotifications,
      // Tüm doküman verisini de logla (debug için)
      allDataKeys: Object.keys(followingData || {})
    });

    // Debug: following listesini de kontrol et
    const following = followingData?.following || [];
    functions.logger.info('🔍 Debug - following listesi:', {
      followingCount: Array.isArray(following) ? following.length : 0,
      following: following
    });

    if (!Array.isArray(followersWithNotifications) || followersWithNotifications.length === 0) {
      functions.logger.warn('⚠️ Bildirim almak isteyen takipçi yok:', {
        userId: followingUserId,
        username: username,
        followersWithNotificationsType: typeof followersWithNotifications,
        followersWithNotificationsValue: followersWithNotifications,
        followingListExists: Array.isArray(following) && following.length > 0,
        followingListCount: Array.isArray(following) ? following.length : 0
      });
      return;
    }

    functions.logger.info(`📢 ${followersWithNotifications.length} takipçiye bildirim gönderiliyor:`, followingUserId);

    // Takipçilerin FCM token'larını al
    const followerDocs = await Promise.all(
      followersWithNotifications.map(followerId => 
        admin.firestore().collection('users').doc(followerId).get()
      )
    );

    const messages = [];
    
    followerDocs.forEach((followerDoc, index) => {
      const followerId = followersWithNotifications[index];
      
      if (!followerDoc.exists) {
        functions.logger.warn(`⚠️ Takipçi dokümanı bulunamadı: ${followerId}`);
        return;
      }
      
      const followerData = followerDoc.data();
      const fcmToken = followerData?.fcmToken;
      
      if (!fcmToken) {
        functions.logger.warn(`⚠️ Takipçinin FCM token'ı yok: ${followerId}`);
        return;
      }
      
      functions.logger.info(`✅ Takipçi için bildirim hazırlanıyor: ${followerId} (token: ${fcmToken.substring(0, 20)}...)`);

      const dealTitle = deal.title || 'Yeni Fırsat';
      const body = dealTitle.length > 50 ? dealTitle.substring(0, 50) + "..." : dealTitle;

      messages.push({
        token: fcmToken,
        notification: {
          title: `👤 ${username} Yeni Bir Fırsat Paylaştı`,
          body: `Takip ettiğiniz ${username} yeni bir fırsat paylaştı: ${body}`,
        },
        data: {
          type: 'follow',
          dealId: dealId,
          followingUserId: followingUserId,
          username: username,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'follow_channel',
            sound: 'default',
            color: '#4CAF50', // Yeşil renk (takip bildirimleri için)
            tag: `follow_${dealId}`, // Benzersiz tag
            // Bildirimi daha belirgin yapmak için
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              'interruption-level': 'active',
              category: 'FOLLOW_NOTIFICATION', // iOS için kategori
            },
          },
        },
      });
    });

    if (messages.length === 0) {
      functions.logger.info('Gönderilecek bildirim yok');
      return;
    }

    // FCM sendEach: 500 limit, 300 batch size
    const batches = [];
    const size = 300;
    for (let i = 0; i < messages.length; i += size) {
      batches.push(messages.slice(i, i + size));
    }

    for (const batch of batches) {
      try {
        functions.logger.info(`📤 ${batch.length} bildirim gönderiliyor...`);
        const resp = await admin.messaging().sendEach(batch);
        functions.logger.info('✅ Takip bildirimleri gönderildi', {
          success: resp.successCount,
          failure: resp.failureCount,
          total: batch.length
        });
        
        if (resp.failureCount > 0) {
          resp.responses.forEach((response, index) => {
            if (!response.success) {
              functions.logger.error(`❌ Bildirim gönderme hatası (${index}):`, response.error);
            }
          });
        }
      } catch (error) {
        functions.logger.error('❌ Takip bildirim hatası:', error);
      }
    }
  } catch (error) {
    functions.logger.error('❌ Takip bildirim genel hatası:', error);
  }
}

/**
 * 1. YENİ FIRSAT GELDİĞİNDE
 */
exports.onDealCreated = functions.firestore
  .document('deals/{dealId}')
  .onCreate(async (snap, context) => {
    const deal = snap.data();
    const dealId = context.params.dealId;

    functions.logger.info('📦 Yeni fırsat eklendi:', dealId, deal.title, 'isApproved:', deal.isApproved);

    // Eğer fırsat zaten onaylı geldiyse, sadece genel kullanıcı bildirimlerini gönder
    if (deal.isApproved === true) {
      functions.logger.info('✅ Fırsat onaylı, genel bildirimler gönderiliyor...');
      
      // Genel bildirimler
      await sendUserNotifications(deal, dealId);
      
      // Anahtar kelime bildirimleri - HERKESİN aldığı kelimeler kontrol edilir
      await sendKeywordNotifications(dealId, deal.title || '', deal.description || '');
      
      // Takip bildirimleri - SADECE kullanıcı tarafından paylaşılan deal'ler için
      await sendFollowNotifications(deal, dealId);
      return;
    }

    // Onaysız fırsat -> SADECE Admin'e bildirim (bot veya kullanıcı farketmez)
    const dealTitle = deal.title || 'Yeni Fırsat';
    const dealPrice = deal.price || 0;
    const shortTitle = dealTitle.length > 50 ? dealTitle.substring(0, 50) + "..." : dealTitle;
    const isUserSubmitted = deal.isUserSubmitted || false;
    const dealSource = isUserSubmitted ? '👤 Kullanıcı' : '🤖 Bot';
    
    const adminPayload = {
      notification: {
        title: `👮‍♂️ Yeni Onay Bekleyen Fırsat (${dealSource})`,
        body: `${shortTitle}\n💰 ${dealPrice} TL`,
      },
      data: {
        type: 'admin_deal',
        dealId: dealId,
        isApproved: 'false',
        isUserSubmitted: isUserSubmitted ? 'true' : 'false',
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'admin_channel',
          sound: 'default',
          color: '#2196F3', // Mavi renk
          tag: `admin_deal_${dealId}`, // Benzersiz tag
          defaultSound: true,
          defaultVibrateTimings: true,
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'interruption-level': 'critical', // iOS için kritik seviye
            category: 'ADMIN_NOTIFICATION',
          },
        },
      },
    };

    try {
      functions.logger.info(`📤 Admin bildirimi gönderiliyor (topic: admin_deals, isApproved: false, isUserSubmitted: ${isUserSubmitted})...`);
      const adminResponse = await admin.messaging().send({
        ...adminPayload,
        topic: 'admin_deals'
      });
      functions.logger.info('✅ Admin bildirimi başarıyla gönderildi:', adminResponse);
    } catch (error) {
      functions.logger.error('❌ Admin bildirimi hatası:', error);
    }
  });

/**
 * 2. FIRSAT GÜNCELLENDİĞİNDE (Onaylandıysa Herkese Bildir + Anahtar Kelime)
 */
exports.onDealUpdated = functions.firestore
  .document('deals/{dealId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    const dealId = context.params.dealId;

    // Sadece onay durumu false -> true olduğunda çalış
    if (oldData.isApproved === false && newData.isApproved === true) {
      functions.logger.info('🎉 Fırsat onaylandı! Bildirimler gönderiliyor:', dealId);
      
      // Genel bildirimler
      await sendUserNotifications(newData, dealId);
      
      // Anahtar kelime bildirimleri - HERKESİN aldığı kelimeler kontrol edilir
      await sendKeywordNotifications(dealId, newData.title || '', newData.description || '');
      
      // Takip bildirimleri - SADECE kullanıcı tarafından paylaşılan deal'ler için
      await sendFollowNotifications(newData, dealId);
    }

    return null;
  });
