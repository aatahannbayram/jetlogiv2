import type { Metadata } from 'next';
import { TrackForm } from '@/components/track-form';
import { lookupShipment } from '@/lib/actions';

export const metadata: Metadata = { title: 'Gönderi Sorgulama' };

export default async function TrackPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const { q } = await searchParams;
  const result = await lookupShipment(q ?? '');

  return (
    <main>
      <header className="page-hero">
        <div className="wrap">
          <p className="kicker" style={{ color: 'var(--accent-deep)' }}>
            Takip
          </p>
          <h1>Gönderi sorgulama</h1>
          <p>
            Eski kurumsal API (`api.jetlogi.net`) bu forma bağlanmaz — body
            içinde kullanıcı adı/şifre isteyen B2B uç kamu sitesine uygun değil.
            Canlı kaynak panel public tracking olunca `TRACKING_API_URL` ile
            bağlanır.
          </p>
        </div>
      </header>
      <section className="section">
        <div className="wrap" style={{ maxWidth: 560 }}>
          <TrackForm defaultQuery={q ?? ''} />
          {result.state === 'unconfigured' ? (
            <p className="banner banner-info" role="status">
              “{result.query}” alındı. Takip API’si henüz bağlı değil
              (`TRACKING_API_URL`). Numara saklanmaz; sonuç uydurulmaz.
            </p>
          ) : null}
          {result.state === 'error' ? (
            <p className="banner banner-warn" role="alert">
              {result.message} (sorgu: {result.query})
            </p>
          ) : null}
          {result.state === 'ok' ? (
            <article className="card" style={{ marginTop: 16 }}>
              <h2>{result.headline}</h2>
              <p className="muted">{result.detail}</p>
            </article>
          ) : null}
        </div>
      </section>
    </main>
  );
}
