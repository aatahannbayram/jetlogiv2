import Link from 'next/link';

export default function NotFound() {
  return (
    <main className="section">
      <div className="wrap">
        <h1>Sayfa yok</h1>
        <p className="muted">Bu adres kurumsal sitede tanımlı değil.</p>
        <p>
          <Link className="more" href="/">
            Anasayfaya dön →
          </Link>
        </p>
      </div>
    </main>
  );
}
