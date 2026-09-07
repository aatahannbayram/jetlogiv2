import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { serviceBySlug, services } from '@/lib/content';

type Params = { slug: string };

export function generateStaticParams() {
  return services.map((s) => ({ slug: s.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<Params>;
}): Promise<Metadata> {
  const { slug } = await params;
  const s = serviceBySlug(slug);
  return { title: s?.title ?? 'Hizmet' };
}

export default async function ServiceDetailPage({
  params,
}: {
  params: Promise<Params>;
}) {
  const { slug } = await params;
  const s = serviceBySlug(slug);
  if (!s) notFound();

  return (
    <main>
      <header className="page-hero">
        <div className="wrap">
          <p className="kicker" style={{ color: 'var(--accent-deep)' }}>
            <Link href="/hizmetler">Hizmetler</Link>
          </p>
          <h1>{s.title}</h1>
          <p>{s.summary}</p>
        </div>
      </header>
      <section className="section">
        <div className="wrap" style={{ maxWidth: 720 }}>
          <p style={{ fontSize: '1.08rem' }}>{s.body}</p>
          <p style={{ marginTop: 28 }}>
            <Link className="more" href="/iletisim">
              Bu hizmet için yazın →
            </Link>
          </p>
        </div>
      </section>
    </main>
  );
}
