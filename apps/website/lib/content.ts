export const brand = {
  name: 'JetLogi',
  tagline: 'Dijital Çağın Lojistik Çözümleri',
  blurb:
    'Türkiye’nin 81 ilinde ve seçili uluslararası hatlarda kurye, kontrollü teslimat ve evrak dağıtımı. Kurumsal müşterinin kendi sürecine oturan, izlenebilir bir saha ağı.',
};

export const nav = [
  { href: '/', label: 'Anasayfa' },
  { href: '/hakkimizda', label: 'Hakkımızda' },
  { href: '/hizmetler', label: 'Hizmetler' },
  { href: '/belgeler', label: 'Belgeler' },
  { href: '/kariyer', label: 'Kariyer' },
  { href: '/iletisim', label: 'Bize Ulaşın' },
  { href: '/kampanyalar', label: 'Kampanyalar' },
  { href: '/takip', label: 'Gönderi Sorgulama' },
] as const;

export const stats = [
  { value: '81', label: 'İl' },
  { value: '99.2%', label: 'Mutlu müşteri' },
  { value: '5', label: 'Saha platformu' },
] as const;

export const modules = [
  {
    title: 'JET Mobil',
    body: 'Kendi yazılım ekibimizin saha uygulaması: görev, zimmet, rota ve teslimat kanıtı tek elde.',
  },
  {
    title: 'Entegrasyon',
    body: 'Müşteri sistemleriyle çift yönlü bağ: gönderi açma, durum ve takip — Integration Hub üzerinden.',
  },
  {
    title: 'Ticket',
    body: 'SLA ve KPI ile izlenen destek: müşteri, şube ve kurye aynı kayıttan konuşur.',
  },
  {
    title: 'Çağrı yönetimi',
    body: 'Çift yönlü arama ve maskeli hat: alıcıya ulaşmak, randevu almak, sonucu kaydetmek.',
  },
  {
    title: 'Raporlama',
    body: 'Teslimat, randevu ve istisna anlık. Operasyon masası tahminle değil veriyle döner.',
  },
] as const;

export type Service = {
  slug: string;
  title: string;
  summary: string;
  body: string;
};

export const services: Service[] = [
  {
    slug: 'evrak-yonetimi',
    title: 'Evrak Yönetimi',
    summary: 'Toplama, sınıflama, zimmet ve teslim — evrakın zinciri kopmasın.',
    body: 'Kurumsal evrakın şubeden alıcıya kadar her adımı kayıt altında. Zimmet, teslim kanıtı ve istisna aynı süreçte yürür; muhaberat ekiplerinin bildiği disiplin, dijital izle birleşir.',
  },
  {
    slug: 'dijital-imza-kyc',
    title: 'Dijital İmza & KYC',
    summary: 'Kimlik doğrulama ve imza, sahada — kontrollü teslimatın omurgası.',
    body: 'Kart, sözleşme ve düzenlemeye tabi ürünlerde kimlik kontrolü teslimatın parçasıdır. KYC adımı atlanırsa iş bitmiş sayılmaz; kanıt panele düşer.',
  },
  {
    slug: 'e-imza-evrak',
    title: 'E-İmza Evrak',
    summary: 'Kâğıt yerine e-imza: evrak dolaşır, imza dijital kalır.',
    body: 'Alıcı sahada imzalar; belge arşive elektronik gider. Fiziksel nüsha gereken yerde hibrit, gerekmeyen yerde tam dijital.',
  },
  {
    slug: 'kredi-karti-dagitimi',
    title: 'Kredi Kartı Dağıtımı',
    summary: 'Bankacılık ürünü: kimlik, seri no, teslim alan — sıkı kontrollü teslimat.',
    body: 'Kart ve benzeri değerli ürünlerde alıcı kimliği, ürün seri numarası ve teslim kanıtı zorunludur. Bu, standart koli dağıtımı değildir; KYC ile aynı aile.',
  },
  {
    slug: 'adresli-dagitim',
    title: 'Adresli Dağıtım',
    summary: 'Kapıya teslim, randevu ve ikinci deneme kurallarıyla.',
    body: 'Klasik adresli dağıtım: randevu, deneme sayısı, iade ve şube teslimi. 81 il ağı, kurumsal SLA’ya göre katmanlanır.',
  },
  {
    slug: 'e-ticaret-dagitimi',
    title: 'E-Ticaret Dağıtımı',
    summary: 'Sipariş hacmi, iade penceresi ve müşteri bildirimiyle e-ticaret hattı.',
    body: 'Pazaryeri ve kendi mağazası olan satıcılar için son mil. Takip numarası müşteriye açık; istisna ticket’a düşer.',
  },
  {
    slug: 'e-ticaret-iade',
    title: 'E-Ticaret İade',
    summary: 'Ters lojistik: alıcıdan satıcıya, kontrol ve zimmetle.',
    body: 'İade, gidişin tersi değil ayrı bir iş. Ürün durumu, paket bütünlüğü ve satıcıya teslim raporu ayrı adımlardır.',
  },
  {
    slug: 'insert-dagitimi',
    title: 'Insert Dağıtımı',
    summary: 'Toplu, çoğu zaman imzasız — yüksek hacim, düşük sürtünme.',
    body: 'Broşür, insert ve benzeri basılı malzeme. İmza gerekmez; bölge ve adet raporu yeter. Standart teslimat profilinden ayrı tutulur.',
  },
  {
    slug: 'muhaberat',
    title: 'Muhaberat',
    summary: 'Kurumlar arası yazışma ve resmi evrak dolaşımı.',
    body: 'Kamu ve özel kurum muhaberatı: zimmet defteri mantığı, dijital kayıt. Evrak yönetimiyle kardeş, resmiyet eşiği daha yüksek.',
  },
  {
    slug: 'ek-hizmetler',
    title: 'Ek Hizmetler',
    summary: 'Montaj, yerinde işlem, özel randevu — çekirdek dağıtımın dışı.',
    body: 'Teslimatın yanında yapılması gereken iş: kurulum, form doldurma, yerinde kontrol. Ayrı ürün tanımı, ayrı SLA.',
  },
  {
    slug: 'telemarketing',
    title: 'Telemarketing',
    summary: 'Saha değil hat: outbound satış ve randevu çağrıları.',
    body: 'Dağıtım ağının çağrı katmanı. Randevu ve bilgilendirme outbound; sonuç CRM ve ticket’a yazılır.',
  },
  {
    slug: 'inbound-outbound',
    title: 'Inbound / Outbound',
    summary: 'Gelen ve giden çağrı merkezi — maskeli hat, kayıt, SLA.',
    body: 'Müşteri arar, biz ararız. Çift yönlü hat, kurye-alıcı görüşmesi ve operasyon masası aynı çağrı yönetiminde toplanır.',
  },
];

export function serviceBySlug(slug: string): Service | undefined {
  return services.find((s) => s.slug === slug);
}

export const careerRoles = [
  'Bayi Denetim ve Mutabakat Sorumlusu',
  'Bayi Operasyon & Uyum Müdürü',
  'Depo Operasyon Sorumlusu',
  'Depo Operasyon Uzmanı',
  'Doğu & Güneydoğu Anadolu Bölge Sorumlusu',
  'Doğu Marmara Bölge Sorumlusu',
  'Eğitim ve Analiz Uzmanı',
  'İç Anadolu Bölge Sorumlusu',
  'İdari İşler Sorumlusu',
  'Kurye Operasyon Uzmanı',
  'Müşteri Deneyimi Uzmanı',
  'Saha Operasyon Müdürü',
] as const;

export const about = {
  lead: 'JetLogi, kurye ve dağıtımı yazılımla işleten bir saha şirketi. Ağ Türkiye’nin 81 iline yayılır; iş ise tek bir “koli götürmek” değil — evrak, kart, e-ticaret, iade ve çağrı aynı operasyon omurgasında durur.',
  paragraphs: [
    'Kurumsal müşteri kendi ERP veya mağaza sisteminden gönderi açar; biz sahayı, zimmeti ve teslim kanıtını yönetiriz. Entegrasyon çift yönlüdür: durum geri yazılır, istisna ticket olur, rapor masaya düşer.',
    'Saha uygulaması (JET Mobil) kendi ekibimizindir. Kurye görev alır, kapıda kimlik veya imza ister, sonucu çevrimdışı bile kaydeder. Şube zimmeti ve destek kaydı aynı panele bağlanır.',
    'Bu site mevcut jetlogi.com’un yeniden yapımıdır: aynı hizmet kataloğu, aynı sorular — gönderi sorgulama, kariyer, acente/kurye başvurusu. Takip ve form bildirimleri canlı API’ye bağlanınca bu sayfalar değişmeden kalır.',
  ],
};

export const documents = [
  {
    title: 'Yetki ve faaliyet',
    body: 'Ulaştırma ve dağıtım faaliyet belgelerimiz talep üzerine paylaşılır. Kamuya açık kopya bu sürüme eklenmedi; iletişim formundan isteyin.',
  },
  {
    title: 'KVKK ve veri',
    body: 'Alıcı kimliği, telefon ve teslim kanıtı KVKK kapsamında işlenir. Aydınlatma metni ve başvuru hakkı için Bize Ulaşın.',
  },
  {
    title: 'ISO / kalite',
    body: 'Kalite ve bilgi güvenliği sertifikaları varsa tarama olarak bu sayfaya konur. Şu an yer tutucu: belge numarası uydurulmaz.',
  },
] as const;
