import type { Metadata } from 'next';
import { about, brand } from '@/lib/content';

export const metadata: Metadata = { title: 'Hakkımızda' };

export default function AboutPage() {
  return (
    <main>
      <header className="page-hero">
        <div className="wrap">
          <p className="kicker" style={{ color: 'var(--accent-deep)' }}>
            Hakkımızda
          </p>
          <h1>Saha şirketi, yazılım omurgası</h1>
          <p>{about.lead}</p>
        </div>
      </header>
      <section className="section">
        <div className="wrap grid-2">
          {about.paragraphs.map((p) => (
            <article className="card" key={p.slice(0, 24)}>
              <p>{p}</p>
            </article>
          ))}
          <article className="card">
            <h2>Kapsam</h2>
            <p className="muted">
              {brand.name} bu sitede kurumsal yüzdür. Kurye uygulaması ve operasyon
              paneli ayrı ürünlerdir; bu sayfalar müşteri, aday ve alıcı içindir.
            </p>
          </article>
        </div>
      </section>
    </main>
  );
}
