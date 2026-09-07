import type { Metadata } from 'next';
import { ContactForm } from '@/components/forms';

export const metadata: Metadata = { title: 'Bize Ulaşın' };

export default function ContactPage() {
  return (
    <main>
      <header className="page-hero">
        <div className="wrap">
          <p className="kicker" style={{ color: 'var(--accent-deep)' }}>
            İletişim
          </p>
          <h1>Operasyon masasına yazın</h1>
          <p>
            Adres ve genel telefon bu sürüme eklenmedi — mevcut sitede de form
            öne çıkıyor. Uydurma iletişim bilgisi yok; form yeterli.
          </p>
        </div>
      </header>
      <section className="section">
        <div className="wrap" style={{ maxWidth: 640 }}>
          <ContactForm />
        </div>
      </section>
    </main>
  );
}
