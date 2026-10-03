import type { Metadata } from 'next';
import { CareerForm, PartnerForm } from '@/components/forms';

export const metadata: Metadata = { title: 'Kariyer' };

export default function CareerPage() {
  return (
    <main>
      <header className="page-hero">
        <div className="wrap">
          <p className="kicker" style={{ color: 'var(--accent-deep)' }}>
            Kariyer
          </p>
          <h1>Saha, depo, bölge, uyum</h1>
          <p>
            Pozisyon listesi mevcut sitedeki başvuru formundan. E-posta bildirimi
            bağlanana kadar gönderim doğrulanır, kuyruğa düşmez.
          </p>
        </div>
      </header>
      <section className="section">
        <div className="wrap grid-2">
          <CareerForm />
          <PartnerForm />
        </div>
      </section>
    </main>
  );
}
