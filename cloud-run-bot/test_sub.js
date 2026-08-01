const { TelegramClient, Api } = require('telegram');
const { StringSession } = require('telegram/sessions');
const fs = require('fs');

async function testSubscribers() {
  const envText = fs.readFileSync('.env', 'utf8');
  const apiIdMatch = envText.match(/TELEGRAM_API_ID=(.+)/);
  const apiHashMatch = envText.match(/TELEGRAM_API_HASH=(.+)/);
  const sessionMatch = envText.match(/TELEGRAM_SESSION_STRING=(.+)/);

  if (!apiIdMatch || !apiHashMatch || !sessionMatch) {
    console.error("Env credentials not found");
    return;
  }

  const client = new TelegramClient(
    new StringSession(sessionMatch[1].trim()),
    parseInt(apiIdMatch[1].trim()),
    apiHashMatch[1].trim(),
    { connectionRetries: 3 }
  );

  await client.connect();
  console.log("Connected to Telegram");

  const channel = await client.getEntity('@indirimkaplani');
  console.log("Channel entity:", {
    title: channel.title,
    username: channel.username,
    participantsCount: channel.participantsCount
  });

  try {
    const full = await client.invoke(new Api.channels.GetFullChannel({ channel: channel }));
    console.log("Full channel participantsCount:", full.fullChat.participantsCount);
  } catch (e) {
    console.error("GetFullChannel error:", e.message);
  }

  await client.disconnect();
  process.exit(0);
}

testSubscribers();
