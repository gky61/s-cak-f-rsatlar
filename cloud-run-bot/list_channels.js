/**
 * Telegram Kanal/Grup Listesi
 * Hesabınızdaki tüm kanal ve grupları ID'leriyle listeler
 */

const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions');

const API_ID = 37462587;
const API_HASH = '35c8bc7cd010dd61eb5a123e2722be41';
const SESSION_STRING = '1BAAOMTQ5LjE1NC4xNjcuOTEAUA6qvKj0rF13DazoNWSTz72hw+4JrkjRgqex0/1w4pO2so1/tLfE8VsfjX9pOarHgS2qV8Kv5aFEb1U9a42I2KnoRcB9iWmBIMAK4PA6jRRNtEivWyMTQCNHN6qGh/EpfBQb8HuTAZCMpA5M8/ZTyNug2ytg6z2xkgxnNj1UccPrLeBqRpw0jqVw3/WoGsGQXk3X56+JUWwBiOFGy9027X4Yo3IDQX+hKxKwaU5JkkkZF1Vp7m2wQaaglI//lKkSkVFauyzuOdA5jSQrD8gXOpqDLFDCGaiksv8vUjlXIg5Lg4EUEvyziKuxooRs/F+pdgSPWFl0+xBQJNrY6fFcnG4=';

(async () => {
  console.log('📡 Telegram Kanal/Grup Listesi');
  console.log('═════════════════════════════════════════');
  console.log('');
  
  const stringSession = new StringSession(SESSION_STRING);
  const client = new TelegramClient(stringSession, API_ID, API_HASH, {
    connectionRetries: 5,
  });

  try {
    await client.connect();
    console.log('✅ Telegram\'a bağlandı!');
    console.log('');
    
    // Tüm diyalogları al (gruplar, kanallar, private chats)
    const dialogs = await client.getDialogs({ limit: 100 });
    
    console.log(`📊 Toplam ${dialogs.length} sohbet bulundu:`);
    console.log('');
    
    let channels = [];
    let groups = [];
    let supergroups = [];
    
    for (const dialog of dialogs) {
      const entity = dialog.entity;
      
      if (!entity) continue;
      
      const id = entity.id?.toString() || 'N/A';
      const title = entity.title || entity.firstName || 'Adsız';
      const username = entity.username ? `@${entity.username}` : '';
      
      if (entity.broadcast) {
        // Kanal
        channels.push({ id, title, username, type: 'Kanal' });
      } else if (entity.megagroup) {
        // Supergroup
        supergroups.push({ id, title, username, type: 'Supergroup' });
      } else if (entity.className === 'Chat') {
        // Normal grup
        groups.push({ id, title, username, type: 'Grup' });
      }
    }
    
    // Kanalları yazdır
    if (channels.length > 0) {
      console.log('📢 KANALLAR:');
      console.log('─────────────────────────────────────────');
      channels.forEach((ch, i) => {
        console.log(`${i + 1}. ${ch.title}`);
        console.log(`   ID: ${ch.id}`);
        if (ch.username) console.log(`   Username: ${ch.username}`);
        console.log('');
      });
    }
    
    // Supergroup'ları yazdır
    if (supergroups.length > 0) {
      console.log('👥 SUPERGRUPLAR:');
      console.log('─────────────────────────────────────────');
      supergroups.forEach((sg, i) => {
        console.log(`${i + 1}. ${sg.title}`);
        console.log(`   ID: -${sg.id}`);
        if (sg.username) console.log(`   Username: ${sg.username}`);
        console.log('');
      });
    }
    
    // Grupları yazdır
    if (groups.length > 0) {
      console.log('💬 GRUPLAR:');
      console.log('─────────────────────────────────────────');
      groups.forEach((gr, i) => {
        console.log(`${i + 1}. ${gr.title}`);
        console.log(`   ID: ${gr.id}`);
        if (gr.username) console.log(`   Username: ${gr.username}`);
        console.log('');
      });
    }
    
    console.log('═════════════════════════════════════════');
    console.log('');
    console.log('💡 Bot\'a eklemek için:');
    console.log('   - Kanal için: @username veya ID kullanın');
    console.log('   - Grup için: -ID şeklinde kullanın');
    console.log('');
    
  } catch (error) {
    console.error('❌ Hata:', error.message);
  } finally {
    await client.disconnect();
    process.exit(0);
  }
})();
