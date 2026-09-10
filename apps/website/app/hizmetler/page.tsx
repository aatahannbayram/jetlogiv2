import type { Metadata } from 'next';
import Link from 'next/link';
import { services } from '@/lib/content';

export const metadata: Metadata = { title: 'Hizmetler' };

export default function ServicesPage() {
  return (
    <main>
      <header className="page-hero">
        <div className="wrap">
          <p className="kicker" style={{ color: 'var(--accent-deep)' }}>
            Hizmetler
          </p>
          <h1>On iki hizmet, tek saha ağı</h1>
          <p>
            Katalog mevcut jetlogi.com ile aynıdır. Her kalem ayrı ürün tanımı ve
            ayrı teslimat kuralı taşır — kart dağıtımı insert ile karışmaz.
          </p>
        </div>
      </header>
      <section className="section">
        <div className="wrap grid-3">
          {services.map((s) => (
            <article className="card" key={s.slug}>
              <h2>{s.title}</h2>
              <p className="muted">{s.summary}</p>
              <Link className="more" href={`/hizmetler/${s.slug}`}>
                Ayrıntılı bilgi
              </Link>
            </article>
          ))}
        </div>
      </section>
    </main>
  );
}
