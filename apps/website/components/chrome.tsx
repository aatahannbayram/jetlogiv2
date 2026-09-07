'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';
import { brand, nav } from '@/lib/content';

export function Header() {
  const path = usePathname();
  const [open, setOpen] = useState(false);

  return (
    <header className="site-header">
      <div className="wrap header-inner">
        <Link href="/" className="brand" onClick={() => setOpen(false)}>
          <span className="brand-mark" aria-hidden />
          {brand.name}
        </Link>
        <button
          type="button"
          className="menu-btn"
          aria-expanded={open}
          aria-controls="site-nav"
          onClick={() => setOpen((v) => !v)}
        >
          Menü
        </button>
        <nav id="site-nav" className={open ? 'nav open' : 'nav'}>
          {nav.map((item) =>
            item.href === '/takip' ? (
              <Link
                key={item.href}
                href={item.href}
                className="nav-cta"
                onClick={() => setOpen(false)}
              >
                {item.label}
              </Link>
            ) : (
              <Link
                key={item.href}
                href={item.href}
                aria-current={path === item.href ? 'page' : undefined}
                onClick={() => setOpen(false)}
              >
                {item.label}
              </Link>
            ),
          )}
        </nav>
      </div>
    </header>
  );
}

export function Footer() {
  return (
    <footer className="site-footer">
      <div className="wrap">
        <div className="footer-grid">
          <div>
            <div className="brand" style={{ marginBottom: 10 }}>
              <span className="brand-mark" aria-hidden />
              {brand.name}
            </div>
            <p className="muted">{brand.tagline}. {brand.blurb}</p>
          </div>
          <div className="footer-nav">
            {nav.slice(0, 4).map((item) => (
              <Link key={item.href} href={item.href}>
                {item.label}
              </Link>
            ))}
          </div>
          <div className="footer-nav">
            {nav.slice(4).map((item) => (
              <Link key={item.href} href={item.href}>
                {item.label}
              </Link>
            ))}
          </div>
        </div>
        <p className="legal">
          © {new Date().getFullYear()} JetLogi. Tüm hakları saklıdır.
        </p>
      </div>
    </footer>
  );
}
