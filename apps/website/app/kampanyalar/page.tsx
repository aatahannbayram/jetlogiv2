import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = { title: 'Kampanyalar' };

export default function CampaignsPage() {
  return (
    <main>
      <header className="page-hero">
        <div className="wrap">
          <p className="kicker" style={{ color: 'var(--accent-deep)' }}>
            Kampanyalar
          </p>
          <h1>Şu an duyurulacak kampanya yok</h1>
          <p>
            Mevcut jetlogi.com’da kampanya menüsü var; canlı metin bu yeniden
            yapımda kopyalanmadı. Gerçek teklif gelince buraya kart olarak
            eklenir — indirim uydurulmaz.
          </p>
        </div>
      </header>
      <section className="section">
        <div className="wrap">
          <article className="card" style={{ maxWidth: 640 }}>
            <h2>Kurumsal teklif</h2>
            <p className="muted">
              Hacim, hat ve SLA’ya göre fiyat. Kampanya değil, sözleşme.
            </p>
            <Link className="more" href="/iletisim">
              Teklif isteyin →
            </Link>
          </article>
        </div>
      </section>
    </main>
  );
}
