type CompanionStickerProps = {
  name: string;
  message?: string;
};

export function CompanionSticker({ name, message = 'Welcome back, trainer!' }: CompanionStickerProps) {
  return (
    <aside className="companion-sticker" aria-label={`${name} companion`}>
      <div className="companion-sticker__bubble">{message}</div>
      <div className="companion-sticker__character" aria-hidden="true">
        <span className="companion-sticker__ears" />
        <span className="companion-sticker__face">🐾</span>
      </div>
      <span className="companion-sticker__name">{name}</span>
    </aside>
  );
}
