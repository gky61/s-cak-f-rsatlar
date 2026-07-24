const assert = require('assert');
const linkScraperService = require('../link_scraper_service');

const testCases = [
  {
    name: 'Link 1 (Staub Döküm Izgara - İndirim Yok)',
    url: 'https://www.amazon.com.tr/Staub-D%C3%B6k%C3%BCm-Izgara-Kulplu-Siyah/dp/B000X20SF2?pd_rd_w=iDLso&content-id=amzn1.sym.eeca1f0f-f560-4eaf-a142-5a802d4a9ab5&pf_rd_p=eeca1f0f-f560-4eaf-a142-5a802d4a9ab5&pf_rd_r=AEAPVJSDC32A1QGF2QKW&pd_rd_wg=SpQ4O&pd_rd_r=df7e476b-f65f-4b31-bc7f-3b23b87f0502&pd_rd_i=B000X20SF2&ref_=pd_hp_d_btf_unk_B000X20SF2',
    expectedDiscounted: 7036.90,
    expectedOriginal: null,
  },
  {
    name: 'Link 2 (MSI Cyborg Laptop)',
    url: 'https://www.amazon.com.tr/MSI-CYBORG-15-B13WEKG-893XTRNN-Bilgisayar/dp/B0GFV4HXKL?ref=dlx_deals_dg_dcl_B0GFV4HXKL_dt_sl14_7c_pi&pf_rd_r=M2W88RW328TMEH33V9JN&pf_rd_p=cee4f41c-1179-4ce5-998c-25ab70a9397c&sbo=RZvfv%2F%2FHxDF%2BO5021pAnSA%3D%3D',
    expectedDiscounted: 48999.00,
    expectedOriginal: 54528.10,
  },
  {
    name: 'Link 3 (LEGO Technic Koenigsegg)',
    url: 'https://www.amazon.com.tr/LEGO-Technic-Koenigsegg-Absolut-42173/dp/B0CWGZTRKJ?ref=dlx_deals_dg_dcl_B0CWGZTRKJ_dt_sl14_7c_pi&pf_rd_r=M2W88RW328TMEH33V9JN&pf_rd_p=cee4f41c-1179-4ce5-998c-25ab70a9397c&sbo=RZvfv%2F%2FHxDF%2BO5021pAnSA%3D%3D',
    expectedDiscounted: 1989.00,
    expectedOriginal: 2327.99,
  },
  {
    name: 'Link 4 (Blade Deodorant)',
    url: 'https://www.amazon.com.tr/Blade-Cool-Fresh-Deodorant-150/dp/B0BD5G1QVP?pd_rd_w=OUcyu&content-id=amzn1.sym.d5de8ed8-2ab2-439f-a56c-fa93755a1cfa&pf_rd_p=d5de8ed8-2ab2-439f-a56c-fa93755a1cfa&pf_rd_r=M2W88RW328TMEH33V9JN&pd_rd_wg=omryV&pd_rd_r=1d9d0e07-855e-41dd-a254-e55a0604af73&pd_rd_i=B0BD5G1QVP&ref_=pd_tdp_d_tdp_dealz_cs_d_B0BD5G1QVP',
    expectedDiscounted: 79.95,
    expectedOriginal: 110.00,
  },
  {
    name: 'Link 5 (Hacı Şakir Sabun - İndirim Yok)',
    url: 'https://www.amazon.com.tr/Hac%C4%B1-%C5%9Eakir-Beyaz-Kal%C4%B1p-Sabun/dp/B086GNDQB4?pd_rd_w=tDpHf&content-id=amzn1.sym.3a523e37-5b49-42dc-af94-fd652d463e69&pf_rd_p=3a523e37-5b49-42dc-af94-fd652d463e69&pf_rd_r=M2W88RW328TMEH33V9JN&pd_rd_wg=omryV&pd_rd_r=1d9d0e07-855e-41dd-a254-e55a0604af73&pd_rd_i=B086GNDQB4&ref_=pd_tdp_d_tdp_dealz_sv_d_B086GNDQB4',
    expectedDiscounted: 99.00,
    expectedOriginal: null,
  },
  {
    name: 'Link 6 (Varta Power Bank)',
    url: 'https://www.amazon.com.tr/Varta-Power-Demand-Bank-20-000/dp/B0CV15ZL3P?ref_=Oct_d_orecs_d_12466497031_2&pd_rd_w=tn7ly&content-id=amzn1.sym.3baccf01-f802-4065-a628-1ea847b40d7a&pf_rd_p=3baccf01-f802-4065-a628-1ea847b40d7a&pf_rd_r=NBKCHGEWZD2VNMZQG2TE&pd_rd_wg=rg2oP&pd_rd_r=68b30022-fbd0-44da-b301-e88e47e39cce&pd_rd_i=B0CV15ZL3P',
    expectedDiscounted: 1199.00,
    expectedOriginal: 1525.96,
  },
  {
    name: 'Link 7 (Ninja Prestige Kahve Makinesi)',
    url: 'https://www.amazon.com.tr/Ninja-Prestige-Dualbrew-Makinesi-CFN802EU/dp/B0FKBJCGC4/ref=pd_rhf_ee_s_pd_crcd_d_sccl_2_17/258-8239719-9767727?pd_rd_w=QBAa1&content-id=amzn1.sym.756d2d56-d336-4f3c-936e-e42257580106&pf_rd_p=756d2d56-d336-4f3c-936e-e42257580106&pf_rd_r=MK0H279XTXSY54R2MJNG&pd_rd_wg=5ULOJ&pd_rd_r=79a11e89-b4b1-48e1-8d57-c5e382bb1381&pd_rd_i=B0FKBJCGC4&psc=1',
    expectedDiscounted: 9999.00,
    expectedOriginal: 13823.14,
  },
];

async function run() {
  console.log('🚀 Starting Node.js Amazon Original Price Unit Tests...\n');
  let passed = 0;

  for (const tc of testCases) {
    console.log(`------------------------------------------------------------`);
    console.log(`Testing: ${tc.name}`);
    console.log(`URL: ${tc.url}`);
    
    const result = await linkScraperService.scrapeProductFromUrl(tc.url);
    console.log(`Scraped Discounted Price: ${result.price} TL (Expected: ${tc.expectedDiscounted} TL)`);
    console.log(`Scraped Original Price:   ${result.originalPrice} TL (Expected: ${tc.expectedOriginal} TL)`);

    assert.ok(result.price !== null, 'Discounted price should not be null');
    assert.strictEqual(result.price, tc.expectedDiscounted, `Discounted price should match ${tc.expectedDiscounted}`);
    assert.strictEqual(result.originalPrice, tc.expectedOriginal, `Original price should match ${tc.expectedOriginal}`);

    if (result.originalPrice !== null && result.price !== null && result.originalPrice > result.price) {
      const discountPercent = Math.round(((result.originalPrice - result.price) / result.originalPrice) * 100);
      console.log(`Calculated Discount Percentage: %${discountPercent}`);
    }
    console.log(`✅ PASSED: ${tc.name}\n`);
    passed++;
  }

  console.log(`🎉 ALL ${passed}/${testCases.length} AMAZON ORIGINAL PRICE TESTS PASSED SUCCESSFULLY!`);
}

run().catch((err) => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
