const AmazonScraper = require('./amazon_scraper');
const HepsiburadaScraper = require('./hepsiburada_scraper');
const N11Scraper = require('./n11_scraper');
const PazaramaScraper = require('./pazarama_scraper');
const VatanScraper = require('./vatan_scraper');
const TrendyolScraper = require('./trendyol_scraper');
const MediaMarktScraper = require('./mediamarkt_scraper');
const IdefixScraper = require('./idefix_scraper');
const ItopyaScraper = require('./itopya_scraper');
const TeknosaScraper = require('./teknosa_scraper');
const MaviScraper = require('./mavi_scraper');
const DefactoScraper = require('./defacto_scraper');
const ZaraScraper = require('./zara_scraper');
const MangoScraper = require('./mango_scraper');
const BeymenScraper = require('./beymen_scraper');
const PttavmScraper = require('./pttavm_scraper');
const IncehesapScraper = require('./incehesap_scraper');
const HavitScraper = require('./havit_scraper');
const MigrosScraper = require('./migros_scraper');
const GetirScraper = require('./getir_scraper');

module.exports = [
  new AmazonScraper(),
  new HepsiburadaScraper(),
  new N11Scraper(),
  new PazaramaScraper(),
  new VatanScraper(),
  new TrendyolScraper(),
  new MediaMarktScraper(),
  new IdefixScraper(),
  new ItopyaScraper(),
  new TeknosaScraper(),
  new MaviScraper(),
  new DefactoScraper(),
  new ZaraScraper(),
  new MangoScraper(),
  new BeymenScraper(),
  new PttavmScraper(),
  new IncehesapScraper(),
  new HavitScraper(),
  new MigrosScraper(),
  new GetirScraper()
];
