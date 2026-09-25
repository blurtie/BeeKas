"use client";

import { useActionState, useState } from "react";
import { copy } from "@/config/copy";
import {
  DESCRIPTION_MAX,
  LISTING_CATEGORIES,
  LISTING_CONDITIONS,
  LISTING_TYPES,
  MEETUP_NOTE_MAX,
  TITLE_MAX,
} from "@/lib/domain/listing";
import { CAMPUSES } from "@/lib/domain/profile";
import { FormMessage } from "@/ui/form-controls";
import { ListingForm } from "@/ui/listing-form";
import { publishListing, type PostFormState, type PostFormValues } from "./actions";
import { PhotoUpload } from "./photo-upload";

type ErrorKey = keyof typeof copy.postForm.errors;
const message = (k: string | undefined) =>
  k === undefined ? undefined : copy.postForm.errors[(k in copy.postForm.errors ? k : "generic") as ErrorKey];

type Props = { userId: string; credits: number; profileCampus: string };

export function PostListingForm({ userId, credits, profileCampus }: Props) {
  const t = copy.postForm;
  const initial: PostFormValues = {
    type: "sale", title: "", category: "", condition: "", description: "",
    price: "", campus: profileCampus, meetup_note: "", image_path: "",
  };
  const [state, action, pending] = useActionState<PostFormState, FormData>(publishListing, { attempt: 0 });
  const values = state.values ?? initial;
  const [type, setType] = useState(values.type);
  const [agreed, setAgreed] = useState(false);

  if (state.publishedId) {
    return (
      <div className="flex flex-col gap-4">
        <FormMessage tone="info">{t.published}</FormMessage>
        {/* Full reload so the credit count is fresh. */}
        <a href="/post" className="flex min-h-11 items-center justify-center rounded-full bg-honey px-4 font-bold text-ink">
          {t.postAnother}
        </a>
      </div>
    );
  }

  const errors = Object.fromEntries(Object.entries(state.fieldErrors ?? {}).map(([k, v]) => [k, message(v)]));
  const noCredits = credits < 1 || state.formError === "no_credits";
  return (
    // key remounts after each attempt so defaultValue shows the submitted values
    // (React resets uncontrolled forms after an action).
    <ListingForm
      key={state.attempt}
      text={t}
      action={action}
      pending={pending}
      values={values}
      errors={errors}
      formError={noCredits ? undefined : message(state.formError)}
      photo={<PhotoUpload userId={userId} initialPath={values.image_path} />}
      types={LISTING_TYPES.map((code) => ({ code, name: copy.listing.types[code] }))}
      categories={LISTING_CATEGORIES.map((code) => ({ code, name: copy.listing.categories[code] }))}
      conditions={LISTING_CONDITIONS.map((code) => ({ code, name: copy.listing.conditions[code] }))}
      campuses={CAMPUSES.map((code) => ({ code, name: copy.profile.campuses[code] }))}
      limits={{ titleMax: TITLE_MAX, descriptionMax: DESCRIPTION_MAX, meetupNoteMax: MEETUP_NOTE_MAX }}
      type={type}
      onTypeChange={setType}
      agreed={agreed}
      onAgreeChange={setAgreed}
      costNote={t.cost(credits)}
      blockedMessage={noCredits ? t.noCredits : undefined}
    />
  );
}
