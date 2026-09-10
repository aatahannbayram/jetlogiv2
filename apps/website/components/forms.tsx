'use client';

import { useActionState } from 'react';
import {
  submitInquiry,
  type InquiryKind,
  type InquiryResult,
} from '@/lib/actions';
import { careerRoles } from '@/lib/content';

function NamePhone({ idPrefix }: { idPrefix: string }) {
  const id = (name: string) => `${idPrefix}-${name}`;
  return (
    <>
      <div className="row">
        <div>
          <label htmlFor={id('firstName')}>Adınız</label>
          <input
            id={id('firstName')}
            name="firstName"
            required
            autoComplete="given-name"
          />
        </div>
        <div>
          <label htmlFor={id('lastName')}>Soyadınız</label>
          <input
            id={id('lastName')}
            name="lastName"
            required
            autoComplete="family-name"
          />
        </div>
      </div>
      <label htmlFor={id('phone')}>Telefon</label>
      <input id={id('phone')} name="phone" type="tel" required autoComplete="tel" />
    </>
  );
}

function Result({ state }: { state: InquiryResult | null }) {
  if (!state) return null;
  if (!state.ok) {
    return <p className="banner banner-warn" role="alert">{state.error}</p>;
  }
  if (state.queued) {
    return (
      <p className="banner banner-ok" role="status">
        Başvurunuz iletildi.
      </p>
    );
  }
  return (
    <p className="banner banner-info" role="status">
      Form doğrulandı. E-posta/webhook henüz bağlı değil — kayıt operasyona
      düşmedi. Canlı bildirim bağlanınca bu mesaj kaybolur.
    </p>
  );
}

export function CareerForm() {
  const action = async (
    _prev: InquiryResult | null,
    form: FormData,
  ): Promise<InquiryResult> => submitInquiry('career', form);
  const [state, formAction, pending] = useActionState(action, null);
  return (
    <form action={formAction} className="panel">
      <h2>Kariyer başvurusu</h2>
      <NamePhone idPrefix="career" />
      <label htmlFor="role">Pozisyon</label>
      <select id="role" name="role" required defaultValue="">
        <option value="" disabled>
          Pozisyon seçiniz
        </option>
        {careerRoles.map((role) => (
          <option key={role} value={role}>
            {role}
          </option>
        ))}
      </select>
      <label htmlFor="career-message">Kendinizi tanıtın</label>
      <textarea id="career-message" name="message" required />
      <button className="btn btn-primary" disabled={pending}>
        {pending ? 'Gönderiliyor…' : 'Başvuruyu gönder'}
      </button>
      <Result state={state} />
    </form>
  );
}

export function PartnerForm() {
  const action = async (
    _prev: InquiryResult | null,
    form: FormData,
  ): Promise<InquiryResult> => submitInquiry('partner', form);
  const [state, formAction, pending] = useActionState(action, null);
  return (
    <form action={formAction} className="panel">
      <h2>İş ortağımız olmak ister misin?</h2>
      <p className="muted">Acente veya kurye başvurusu.</p>
      <NamePhone idPrefix="partner" />
      <div className="row">
        <div>
          <label htmlFor="partnerType">Başvuru tipi</label>
          <select id="partnerType" name="partnerType" required defaultValue="">
            <option value="" disabled>
              Seçiniz
            </option>
            <option value="acenta">Acente</option>
            <option value="kurye">Kurye</option>
          </select>
        </div>
        <div>
          <label htmlFor="transport">Taşıma türü</label>
          <select id="transport" name="transport" defaultValue="">
            <option value="">Belirtmek istemiyorum</option>
            <option value="motorsiklet">Motorsiklet</option>
            <option value="arac">Araç</option>
            <option value="yaya">Yaya</option>
          </select>
        </div>
      </div>
      <label htmlFor="partner-city">Şehir</label>
      <input id="partner-city" name="city" required />
      <label htmlFor="partner-message">Mesajınız</label>
      <textarea id="partner-message" name="message" required />
      <button className="btn btn-primary" disabled={pending}>
        {pending ? 'Gönderiliyor…' : 'Başvuru gönder'}
      </button>
      <Result state={state} />
    </form>
  );
}

export function ContactForm({ kind = 'contact' }: { kind?: InquiryKind }) {
  const action = async (
    _prev: InquiryResult | null,
    form: FormData,
  ): Promise<InquiryResult> => submitInquiry(kind, form);
  const [state, formAction, pending] = useActionState(action, null);
  return (
    <form action={formAction} className="panel">
      <h2>Bize yazın</h2>
      <NamePhone idPrefix="contact" />
      <label htmlFor="contact-message">Mesajınız</label>
      <textarea id="contact-message" name="message" required />
      <button className="btn btn-primary" disabled={pending}>
        {pending ? 'Gönderiliyor…' : 'Gönder'}
      </button>
      <Result state={state} />
    </form>
  );
}
