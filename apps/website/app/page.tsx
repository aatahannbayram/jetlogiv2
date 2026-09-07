import Link from 'next/link';
import { TrackForm } from '@/components/track-form';
import { brand, modules, services, stats } from '@/lib/content';

export default function HomePage() {
  return (
    <>
      <section className="hero">
        <div className="wrap hero-grid">
          <div>
            <p className="kicker">{brand.name}</p>
            <h1>{brand.tagline}</h1>
            <p className="lede">{brand.blurb}</p>
            <Link href="/hizmetler" className="btn btn-ghost">
              Hizmetleri gör
            </Link>
          </div>
          <TrackForm dark />
        </div>
      </section>

      <div className="wrap">
        <div className="stats">
          {stats.map((s) => (
            <div className="stat" key={s.label}>
              <strong>{s.value}</strong>
              <span className="muted">{s.label}</span>
            </div>
          ))}
        </div>
      </div>

      <section className="section">
        <div className="wrap">
          <div className="section-head">
            <div>
              <p className="kicker" style={{ color: 'var(--accent-deep)' }}>
                Platform
              </p>
              <h2>Saha, entegrasyon ve masa aynı omurga</h2>
            </div>
            <p className="muted" style={{ maxWidth: 360 }}>
              Mevcut jetlogi.com’daki JET Mobil, entegrasyon, ticket, çağrı ve
              raporlama modüllerinin karşılığı.
            </p>
          </div>
          <div className="grid-3">
            {modules.map((m) => (
              <article className="card" key={m.title}>
                <h3>{m.title}</h3>
                <p className="muted">{m.body}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <div className="section-head">
            <div>
              <p className="kicker" style={{ color: 'var(--accent-deep)' }}>
                Hizmetler
              </p>
              <h2>Dağıtım bir tür değil, katalog</h2>
            </div>
            <Link href="/hizmetler" className="more">
              Tüm hizmetler →
            </Link>
          </div>
          <div className="grid-4">
            {services.map((s) => (
              <article className="card" key={s.slug}>
                <h3>{s.title}</h3>
                <p className="muted">{s.summary}</p>
                <Link className="more" href={`/hizmetler/${s.slug}`}>
                  Ayrıntılı bilgi
                </Link>
              </article>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
