"use client";

import { useEffect, useState, type ChangeEvent } from "react";
import { copy } from "@/config/copy";
import { fitWithin, LISTING_PHOTO_BUCKET, PHOTO_MAX_BYTES, photoPath } from "@/lib/domain/listing-photo";
import { createClient } from "@/lib/supabase/client";
import { PhotoPicker } from "@/ui/photo-picker";

type ErrorKey = keyof typeof copy.listingPhoto.errors;
type Props = { userId: string; name?: string; initialPath?: string };

// Decodes via <img> (works for every format the browser can show, e.g. HEIC on
// iPhone, and applies EXIF orientation), then resizes to fit PHOTO_MAX_SIDE and
// re-encodes as JPEG, which also strips EXIF such as GPS.
async function compress(file: File): Promise<Blob> {
  const url = URL.createObjectURL(file);
  try {
    const img = new Image();
    img.src = url;
    await img.decode();
    const { width, height } = fitWithin(img.naturalWidth, img.naturalHeight);
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    canvas.getContext("2d")!.drawImage(img, 0, 0, width, height);
    return await new Promise((resolve, reject) =>
      canvas.toBlob((b) => (b ? resolve(b) : reject(new Error("toBlob"))), "image/jpeg", 0.82),
    );
  } finally {
    URL.revokeObjectURL(url);
  }
}

// Uploads one listing photo and exposes its storage path as a hidden form field.
export function PhotoUpload({ userId, name = "image_path", initialPath = "" }: Props) {
  const t = copy.listingPhoto;
  const [path, setPath] = useState(initialPath);
  // A photo kept from an earlier attempt is shown from its public URL.
  const [preview, setPreview] = useState<string | null>(() =>
    initialPath ? createClient().storage.from(LISTING_PHOTO_BUCKET).getPublicUrl(initialPath).data.publicUrl : null,
  );
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<{ tone: "error" | "info"; text: string }>();

  useEffect(() => () => void (preview?.startsWith("blob:") && URL.revokeObjectURL(preview)), [preview]);

  async function onChange(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    const fail = (key: ErrorKey) => setStatus({ tone: "error", text: t.errors[key] });
    // Some Android pickers report an empty type; let decoding decide then.
    if (file.type && !file.type.startsWith("image/")) return fail("not_image");

    setBusy(true);
    setStatus({ tone: "info", text: t.uploading });
    try {
      let blob: Blob;
      try {
        blob = await compress(file);
      } catch {
        return fail("unreadable");
      }
      if (blob.size > PHOTO_MAX_BYTES) return fail("too_large");

      const target = photoPath(userId, crypto.randomUUID());
      const { error } = await createClient()
        .storage.from(LISTING_PHOTO_BUCKET)
        .upload(target, blob, { contentType: "image/jpeg", upsert: false });
      if (error) return fail("upload_failed");

      setPath(target);
      setPreview(URL.createObjectURL(blob));
      setStatus({ tone: "info", text: t.uploaded });
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <PhotoPicker
        label={t.label}
        cameraLabel={t.camera}
        chooseLabel={path ? t.change : t.choose}
        warning={t.warning}
        previewUrl={preview}
        previewAlt={t.previewAlt}
        busy={busy}
        status={status}
        onChange={onChange}
      />
      <input type="hidden" name={name} value={path} />
    </>
  );
}
