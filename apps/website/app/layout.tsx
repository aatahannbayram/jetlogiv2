import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import { Instrument_Sans, Newsreader } from 'next/font/google';
import { Footer, Header } from '@/components/chrome';
import { brand } from '@/lib/content';
import './globals.css';

const sans = Instrument_Sans({
  subsets: ['latin', 'latin-ext'],
  variable: '--font-sans',
  display: 'swap',
});

const serif = Newsreader({
  subsets: ['latin', 'latin-ext'],
  variable: '--font-serif',
  display: 'swap',
});

export const metadata: Metadata = {
  title: {
    default: `${brand.name} — ${brand.tagline}`,
    template: `%s · ${brand.name}`,
  },
  description: brand.blurb,
  icons: { icon: '/favicon.png' },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="tr" className={`${sans.variable} ${serif.variable}`}>
      <body>
        <a className="skip" href="#icerik">
          İçeriğe geç
        </a>
        <Header />
        <div id="icerik">{children}</div>
        <Footer />
      </body>
    </html>
  );
}
