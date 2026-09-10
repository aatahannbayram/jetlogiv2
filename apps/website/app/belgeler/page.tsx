import type { Metadata } from 'next';
import Link from 'next/link';
import { documents } from '@/lib/content';

export const metadata: Metadata = { title: 'Belgeler' };

export default function DocumentsPage() {
  return (
    <main>
      <header className="page-hero">
        <div className="wrap">
          <p className="kicker" style={{ color: 'var(--accent-deep)' }}>
            Belgeler
          </p>
          <h1>Yetki, KVKK, kalite</h1>
          <p>
            Sertifika numarası uydurulmaz. Tarama veya PDF elimizde olunca bu
            sayfaya konur; şimdilik talep yolu açık.
          </p>
        </div>
      </header>
      <section className="section">
        <div className="wrap grid-3">
          {documents.map((d) => (
            <article className="card" key={d.title}>
              <h2>{d.title}</h2>
              <p className="muted">{d.body}</p>
            </article>
          ))}
        </div>
        <div className="wrap" style={{ marginTop: 28 }}>
          <Link className="more" href="/iletisim">
            Belge talebi için yazın →
          </Link>
        </div>
      </section>
    </main>
  );
}
