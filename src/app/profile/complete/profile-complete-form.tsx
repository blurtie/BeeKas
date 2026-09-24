"use client";

import { useActionState } from "react";
import { copy } from "@/config/copy";
import { BINUSIANS, CAMPUSES, MAJOR_GROUPS, NICKNAME_MAX, OTHER_MAJOR } from "@/lib/domain/profile";
import { ProfileForm } from "@/ui/profile-form";
import { saveProfile, type ProfileFormState, type ProfileFormValues } from "./actions";

type ErrorKey = keyof typeof copy.profile.errors;
const message = (k: string | undefined) =>
  k === undefined ? undefined : copy.profile.errors[(k in copy.profile.errors ? k : "save_failed") as ErrorKey];

type Props = {
  email: string;
  userType: "student" | "staff";
  initial: ProfileFormValues;
  next: string;
};

export function ProfileCompleteForm({ email, userType, initial, next }: Props) {
  const [state, action, pending] = useActionState<ProfileFormState, FormData>(saveProfile, { attempt: 0 });
  const errors = Object.fromEntries(
    Object.entries(state.fieldErrors ?? {}).map(([k, v]) => [k, message(v)]),
  );
  return (
    // key remounts the form after each attempt so defaultValue shows the
    // submitted values (React resets uncontrolled forms after an action).
    <ProfileForm
      key={state.attempt}
      text={{ ...copy.profile, title: copy.profile.completeTitle, intro: copy.profile.completeIntro }}
      action={action}
      pending={pending}
      email={email}
      userTypeLabel={copy.profile.userTypes[userType]}
      isStudent={userType === "student"}
      values={state.values ?? initial}
      errors={errors}
      formError={message(state.formError)}
      next={next}
      campuses={CAMPUSES.map((code) => ({ code, name: copy.profile.campuses[code] }))}
      majorGroups={MAJOR_GROUPS}
      otherMajor={OTHER_MAJOR}
      binusians={BINUSIANS}
      nicknameMax={NICKNAME_MAX}
    />
  );
}
