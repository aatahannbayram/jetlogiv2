export function TrackForm({
  defaultQuery = '',
  dark = false,
}: {
  defaultQuery?: string;
  dark?: boolean;
}) {
  return (
    <form action="/takip" method="get" className={dark ? 'track-card' : 'panel'}>
      <h2>Gönderi sorgula</h2>
      <p className="muted">Takip numaranızı yazın. Sonuç aynı sayfada açılır.</p>
      <label htmlFor="q">Takip numarası</label>
      <input
        id="q"
        name="q"
        required
        defaultValue={defaultQuery}
        placeholder="Takip numaranız…"
        autoComplete="off"
      />
      <button className="btn btn-primary" type="submit">
        Gönderi takibi
      </button>
    </form>
  );
}
