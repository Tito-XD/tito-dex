/** Phase 4 — Android Storage Access Framework file picking adapter. */
export type FilePickResult = {
  name: string;
  uri: string;
};

export async function pickSaveFile(): Promise<FilePickResult | null> {
  return null;
}
