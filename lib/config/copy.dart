import 'package:flutter/foundation.dart';

/// All UI text, in two maps (D-11). English is the default.
enum Lang { en, id }

/// The interface language; BeeLanguageScope rebuilds the screens when it
/// changes, and main.dart keeps it on the device.
final language = ValueNotifier(Lang.en);

String t(String key) => copy[language.value]![key]!;

/// A stored language name back to [Lang]; unknown or missing is English.
Lang langFrom(String? name) => Lang.values.asNameMap()[name] ?? Lang.en;

/// Version of the L7 consent text (consent* keys), stored by record_consent
/// (D-20). Change it whenever that text changes.
const consentVersion = '2026-10-07';

const copy = <Lang, Map<String, String>>{
  Lang.en: {
    'back': 'Back',
    'showPassword': 'Show password',
    'hidePassword': 'Hide password',
    'signIn': 'Sign in',
    'register': 'Register',
    'next': 'Next',
    'forgotPassword': 'Forgot password?',
    'password': 'Password',
    'fullName': 'Full name',
    'fullNameHint': 'John Doe',
    'fullNameRequired': 'Enter your full name.',
    'registerDataWarning':
        'Make sure your details are correct and match your BINUS identity.',
    'errorInvalidEmailDomain':
        'Use your BINUS email (@binus.ac.id or @binus.edu).',
    'errorAccountTypeNotAllowed':
        'Account type is set automatically for @binus.ac.id.',
    'errorAccountTypeRequired': 'Choose Lecturer or Staff.',
    'errorInvalidCampus': 'Choose your campus.',
    'errorPhoneRequired': 'Enter your phone number.',
    'errorInvalidPhone': 'Enter a valid phone number.',
    // Generic on purpose: never says the number belongs to another account.
    'errorPhoneTaken': "This number can't be used. Try another number or skip.",
    'errorSignupUnknown': 'Registration failed. Please try again.',
    'registerTitle': 'Your details',
    'registerSubtitle': 'Fill in the details below to continue registering.',
    'registerStep': 'Step {n} of 3',
    'emailBinus': 'BINUS email',
    'emailHint': 'john.doe@binus.ac.id',
    'phone': 'Phone number',
    'phoneHint': '+62 812 3456 7890',
    'phoneOptional': 'Phone number (optional)',
    'phoneHelper': 'Optional. Only used by the BeeKas team if we need to reach you; never shown to other users.',
    'accountType': 'Account type',
    'accountTypeHint': 'Choose Lecturer or Staff',
    'accountType_student': 'Student',
    'accountType_lecturer': 'Lecturer',
    'accountType_staff': 'Staff',
    'campus': 'Campus',
    'campusHint': 'Choose your campus',
    'campus_kemanggisan': 'Kampus Binus Kemanggisan',
    'campus_senayan': 'Kampus Binus Senayan',
    'campus_alam_sutera': 'Kampus Binus Alam Sutera',
    'campus_base': 'Kampus Binus BASE',
    'campus_bekasi': 'Kampus Binus Bekasi',
    'campus_bandung': 'Kampus Binus Bandung',
    'campus_malang': 'Kampus Binus Malang',
    'campus_semarang': 'Kampus Binus Semarang',
    'campus_online': 'BINUS Online',
    'errorEmailRequired': 'Enter your BINUS email.',
    'errorNetwork':
        "Can't reach the server. Check your connection and try again.",
    'codeSent': 'We sent a 6-digit code to your email.',
    'errorInvalidCode': 'The code is wrong or has expired.',
    'errorTooSoon': 'Please wait before requesting a new code.',
    'errorWeakPassword': "The password doesn't meet the requirements yet.",
    'otpTitle': 'Verify your email',
    'otpSubtitle': 'Enter the 6-digit code we sent to {email}.',
    'otpCode': 'Verification code',
    'otpHint': '123456',
    'errorCodeRequired': 'Enter the 6-digit code.',
    'verify': 'Verify',
    'resendCode': 'Resend code',
    'resendIn': 'Resend in {s}s',
    'emailRegistered': 'This email is already registered. Sign in instead.',
    'phoneTitle': 'Phone number',
    'phoneSubtitle': "Your phone number hasn't been saved yet. Enter another number or skip.",
    'skip': 'Skip',
    'phoneKept': 'The phone number {phone} from your earlier registration is kept, not the one you just entered.',
    'passwordTitle': 'Create a password',
    'passwordSubtitle': "You'll use this password to sign in to BeeKas.",
    'passwordConfirm': 'Confirm password',
    'passwordHelper': "Don't use your Binusmaya password or any other account's. Create a password just for BeeKas.",
    'ruleMinLength': 'At least 8 characters',
    'ruleLetter': 'Contains a letter',
    'ruleDigit': 'Contains a number',
    'ruleMatch': 'Matches the confirmation',
    'passwordSaved': 'Password saved.',
    'consentTitle': 'Data consent',
    'consentSubtitle':
        'Before taking any photo, read how BeeKas handles your data.',
    'consentDataLabel': 'Data we collect',
    'consentData': 'A photo of your ID card and a photo of your face.',
    'consentPurposeLabel': 'Purpose',
    'consentPurpose': 'To make sure the account owner is part of BINUS.',
    'consentViewerLabel': 'Who sees it',
    'consentViewer': 'Only BeeKas admins.',
    'consentRetentionLabel': 'How long we keep it',
    'consentRetention': 'Deleted no later than 30 days after review.',
    'consentAgree': 'I agree that BeeKas processes my ID card photo and face photo as described above.',
    'card_student': 'Flazz card',
    'card_lecturer': 'lecturer ID card',
    'card_staff': 'staff ID card',
    'cardTitle': 'Verify your BINUS identity',
    'cardSubtitle': 'Take a photo of your {card} to verify your account. Make sure the photo is clear and not blurry.',
    'cardTake': 'Take a photo of your {card}',
    'cardFormat': 'Format: JPG/PNG • Max. 5 MB',
    'tipLight': 'Enough light, no glare',
    'tipSharp': 'Not blurry',
    'tipReadable': 'Name and details readable',
    'takePhoto': 'Take photo',
    'errorCameraDenied': 'BeeKas needs camera access to take your verification photos. Allow the camera in Settings.',
    'openSettings': 'Open Settings',
    'errorPhotoTooLarge': 'The photo is larger than 5 MB. Take it again.',
    'errorPhotoFailed': "Couldn't take the photo. Try again.",
    'cardConfirmTitle': 'Check your card photo',
    'cardConfirmSubtitle':
        'Make sure the photo of your {card} is clear and correct.',
    'cardPreview': 'Photo of your {card}',
    'checkClear': 'Card is clearly visible',
    'checkMatches': 'Details match your account',
    'checkNoGlare': 'Not blurry, no glare',
    'retake': 'Retake',
    'usePhoto': 'Use photo',
    'selfieTitle': 'Verify your face',
    'selfieSubtitle':
        'Take a selfie so we can match it with the photo on your {card}.',
    'tipFaceLight': 'Use enough light',
    'tipFaceClear': 'Make sure your face is clear and not covered. A hijab or headscarf is fine.',
    'tipFaceCover': "Don't wear glasses, a hat, a mask, or anything else covering your face",
    'tipFaceClothes': 'Wear modest clothing',
    'startVerification': 'Start verification',
    'selfiePreview': 'Your selfie',
    'send': 'Send',
    'errorSendFailed': "Couldn't send your photos. Try again.",
    'errorPhotosMissing': "Your photos didn't arrive. Tap Send to try again.",
    'errorAlreadyApproved':
        'Your account is already verified. Sign in again to continue.',
    'errorStatusRejected': 'Your earlier submission was rejected. Sign in again to see why and resend.',
    'errorStatusIncomplete':
        "Your photos haven't been sent yet. Tap Send to try again.",
    'pendingTitle': 'Verification in progress',
    'pendingBody': "We've received your details. The BeeKas team will verify them within 1×24 hours. You'll get a notification when it's done.",
    'pendingTipsTitle': 'Tips:',
    'pendingTipData': 'Make sure the details you entered are correct',
    'pendingTipPhoto': 'Use clear, sharp photos',
    'pendingTipHelp':
        "If there's no update within 1×24 hours, contact us through Help.",
    'browseCatalog': 'Browse catalog',
    'signOut': 'Sign out',
    'errorInvalidCredentials': 'Wrong email or password.',
    'errorRateLimited': 'Too many attempts. Wait a few minutes and try again.',
    'errorSignInFailed': 'Sign-in failed. Please try again.',
    'onboardingTagline': 'Sell, Buy, Share at BINUS',
    'onboardingCommunity': 'For the community of',
    'onboardingRegister': 'Create an account',
    'languageLabel': 'Language: {name}',
    'onboarding1Body': 'BeeKas is a preloved marketplace just for the BINUS community. Buy and sell used items safely, among fellow Binusians.',
    'onboarding2Pre': 'Find Items ',
    'onboarding2Mark': 'Without',
    'onboarding2Post': ' the Hassle',
    'onboarding2Body': 'Everything is neatly organised in a catalog. No more scrolling social media to find the preloved item you want.',
    'onboarding3Pre': 'More ',
    'onboarding3Mark': 'Trusted',
    'onboarding3Post': ' Deals',
    'onboarding3Body': 'Every item shows Available, Booked, or Sold. Sellers show their name, status (Student/Lecturer/Staff), and campus.',
    'onboarding4Pre': 'Ready to ',
    'onboarding4Mark': 'Buy and Sell',
    'onboarding4Post': ' on Campus?',
    'onboarding4Body': 'Snap your item, list it in minutes, then chat with buyers in BeeKas and meet for COD on campus.',
    'signInTitle': 'Welcome to ',
    'signInTitleEnd': '!',
    'signInSubtitle': 'Sign in to continue to the BINUS community marketplace.',
    'email': 'Email',
    'emailRequired': 'Enter your email.',
    'passwordRequired': 'Enter your password.',
    'noAccount': "Don't have an account?",
    'browseAsGuest': 'Browse catalog as guest',
    'legalReminder': 'By signing in or registering, you agree to the',
    'and': 'and',
    'terms': 'Terms & Conditions',
    'privacy': 'Privacy Policy',
    'legalReadMore': 'Read more in the',
    'legalDraftMarker': '[DRAFT — awaiting team]',
    // Translated from notes/kebijakan-privasi-sk-draf.md (draft 0.1).
    'privacyBody': '''Draft version 0.1. Effective from [release date].

BeeKas collects only the data it needs to make sure every user is part of BINUS, and uses it only to run the marketplace. We do not sell data and do not use it for advertising.

# 1. Who we are

BeeKas is a marketplace for selling, buying, and donating second-hand goods for the BINUS community, built by a student team in the Venture Creation course (ENPR6312001). BeeKas is not an official service of Universitas Bina Nusantara.

The person responsible for personal data is the BeeKas CTO. Contact us at beekas2026@gmail.com.

# 2. Data we collect

For each item: when it is collected, whether it is required, and what it is for.

- Full name, BINUS email, account type (student/lecturer/staff), campus — at registration, required. To create your account and check your identity.

- Phone number — at registration, optional. Only used by the BeeKas team if we need to reach you; never shown to other users.

- Password — at registration, required. To sign in to your account. Stored as a hash; the team cannot see it.

- Photo of your BINUS ID card and photo of your face (selfie) — identity verification, required for full access. An admin matches your face and the card details with your registration details.

- Proof of consent (time and text version) — when you agree, required. Proof that you agreed to the use of your photos.

- Verification history (status, reviewing admin, time, rejection reason, note) — after review, automatic. A record of the review and for handling complaints.

- Batch year (BINUSIAN) — Edit Profile, optional. Shown on your profile; not verified.

- Items you list (photos, title, description, price, category, condition) — when listing an item, required to list. Shown in the catalog.

- Chat messages — when chatting, automatic. To agree on the transaction and COD.

- Bookings, orders, COD location and time — when transacting, automatic. To run 24-hour bookings and orders.

- Reviews, ratings, and the accounts you follow — when you give them or follow, optional. Shown on profiles and items.

- Listing quota purchases [KONFIRMASI: what data is stored, e.g. QRIS transfer proof] — when buying quota, required to buy. Payment confirmation by an admin.

Data stored only on your device: language choice, onboarding status, and sign-in session.

What we do not collect: student ID number (NIM), major, and GPS location. Location data inside verification photos is removed before upload. [KONFIRMASI: also applies to item photos.]

# 3. Who can see your data

- ID card photo and selfie: only admins, namely the five BeeKas team members, each with their own account.

- Phone number: you and admins.

- BINUS email: you and admins. [KONFIRMASI: not shown to other users]

- Name, campus, account type, verified badge, items, reviews: other users and guests browsing the catalog. [KONFIRMASI: what exactly is shown to guests]

- Chat messages: you and the person you chat with. [KONFIRMASI: whether admins may read chats when there is a report]

- Verification history: you (your own history) and admins.

# 4. Other parties that process data

- Supabase: database, authentication, and photo storage. [KONFIRMASI: server location. If outside Indonesia, transfer of data abroad must meet the requirements of the PDP Law.]

- Email provider: sends OTP codes and verification result emails. [KONFIRMASI: provider not yet chosen.]

- Gmail: receives the Help emails you send to beekas2026@gmail.com.

- If push notifications or AI listing creation are added later, their providers will be added here before those features are used.

We do not sell or rent data to anyone.

# 5. How long data is kept

- ID card photo and selfie: deleted no later than 30 days after verification is approved or rejected.

- Verification history: kept after the photos are deleted, for as long as the account exists. [KONFIRMASI: how long after the account is deleted.]

- Account data, items, chats, and reviews: while the account is active. [KONFIRMASI: deletion deadline after the account is closed.]

- If BeeKas is transferred to another party, including BINUS, we will notify users before the data is transferred.

# 6. How we protect data

- Verification photos are kept in private storage that is not publicly accessible.

- Access rules in the database limit who can read what, not just the app's screens.

- Every admin has their own account, so every approval and rejection is recorded under the name of the reviewing admin.

# 7. Your rights

Under the Personal Data Protection Law (Law No. 27 of 2022), you can request:

- a copy of your personal data;

- correction of incorrect data;

- deletion of your account and personal data;

- withdrawal of consent to the use of your verification photos. As a result, full access is revoked until you verify again. [KONFIRMASI: the withdrawal flow is not built yet.]

Send requests to beekas2026@gmail.com from your BINUS email. We reply within [KONFIRMASI: deadline; to be checked against the PDP Law].

# 8. If a data breach occurs

We notify affected users in writing, stating which data was affected, when, and the steps we are taking. [KONFIRMASI: notification deadline under the PDP Law.]

# 9. Users under 18

[KONFIRMASI: some new students may be under 18. The PDP Law requires consent from a parent or guardian for children's data. The team needs to decide whether to set an age limit or add a consent step.]

# 10. Changes to this policy

Changes are announced in the app. If the use of verification photos changes, you will be asked to agree again before continuing.''',
    'termsBody': '''Draft version 0.1. Effective from [release date].

By registering for or using BeeKas, you agree to these terms. BeeKas connects sellers and buyers in the BINUS community; transactions and payments happen directly between you during COD on campus.

# 1. Who may use BeeKas

- Guests without an account may browse the catalog.

- Accounts are only for owners of an active BINUS email (@binus.ac.id or @binus.edu). Alumni whose @binus.ac.id email is still active register as students.

- One person, one account. Accounts may not be lent, sold, or used by someone else.

- [KONFIRMASI: minimum age, see Privacy Policy section 9.]

# 2. Account and verification

- Registration details must be correct and match your BINUS ID card.

- Full access (contacting sellers, buying, listing items) only opens after the team verifies your ID card photo and selfie. Review is completed within 1×24 hours, including weekends and public holidays.

- If rejected, you see the reasons and may resend your photos. There is no limit yet on the number of resubmissions.

- Create a password just for BeeKas. Do not use your Binusmaya password or that of another account.

- You are responsible for all activity on your account. If you suspect someone else is using your account, contact Help right away.

# 3. Listing items

- You can sell items or donate them. Donated items are given to the buyer for free.

- Fee: Rp1,000 per listing, including donation listings. The fee is paid through a prepaid listing quota package to the BeeKas team's QRIS, then confirmed by an admin. [KONFIRMASI: package prices, quota validity period, and whether quota is refundable.]

- Photos must be real photos of the item being sold. Descriptions and condition must be honest, including defects or damage.

- Strikethrough prices may only be used if they match a price that actually applied before. Fake original prices are prohibited.

- Delete or mark as sold any item that is no longer available.

# 4. Prohibited items

- Illegal goods, narcotics, prescription-only drugs, and drugs without a distribution permit.

- Weapons, explosives, and dangerous goods.

- Stolen, counterfeit, or pirated goods, including pirated software and books.

- Identity cards, Flazz cards, or documents belonging to anyone.

- Digital accounts, vouchers that may not be resold, and assignment or exam jockey services.

- Adult content.

- [KONFIRMASI: alcohol, cigarettes and vapes, food, animals, and over-the-counter drugs.]

# 5. Booking, buying, and COD

- 24-Hour Booking: the item is held for you for 24 hours without payment. After 24 hours with no follow-up, the booking is cancelled automatically and the item is available again. [KONFIRMASI: whether the seller may extend it.]

- Buy Now: you confirm the order, then the seller processes it.

- COD on campus: location and time are agreed through chat in the app. Pay the seller directly when you meet. There is no delivery.

- Check the item before paying. Choose a busy place on campus.

- BeeKas does not hold transaction money and is not a party to the sale. Disputes are settled between seller and buyer; the team can help mediate through Help.

# 6. Chat, reviews, and conduct

- Be polite. Harassment, threats, hate speech, and spam are prohibited.

- Do not share other people's personal data, including photos or phone numbers, without their permission.

- Reviews must be honest and based on transactions that actually happened. [KONFIRMASI: reviews only after the order is completed.]

- Do not use BeeKas to defraud others or to move transactions outside the app to avoid these rules.

# 7. Violations

The BeeKas team may remove listings, restrict features, or close accounts that violate these terms. Report violations through Help (beekas2026@gmail.com). [KONFIRMASI: in-app report and block features.]

# 8. Limitation of liability

BeeKas is a student project and is provided as is. We try to keep the app running and secure, but we do not guarantee the quality of items, the honesty of users, or the outcome of transactions. Identity verification makes sure users are part of BINUS; it does not guarantee their conduct.

# 9. Changes and governing law

Changes to these terms are announced in the app. These terms are governed by the laws of the Republic of Indonesia.''',
    'rejectedTitle': 'Verification rejected',
    'rejectedBody': 'Your submission was not approved for these reasons:',
    'rejectedNote': 'Note from the team',
    'rejectedResendHint':
        'Send a new card photo and selfie. Your details stay as they are.',
    'resendVerification': 'Resend',
    'resetTitle': 'Forgot password',
    'resetSubtitle':
        "Enter your BINUS email. We'll send a code to set a new password.",
    'sendCode': 'Send code',
    'resetCodeTitle': 'Enter the code',
    'resetCodeSubtitle': 'Enter the 6-digit code for {email}.',
    'resetCodeSent': 'If this email is registered, we sent a code to it.',
    'resetPasswordTitle': 'New password',
    'savePassword': 'Save password',
    'errorResetFailed': 'Could not reset the password. Please try again.',
    'errorNotPending': 'This account is no longer waiting for review.',
    'errorNotAdmin': 'Only admins can review verifications.',
    'errorReasonMissing': 'A reason is required to reject.',
    'reject': 'Reject',
    'rejectTitle': 'Reject {name}?',
    'rejectReasons': 'Reasons (choose at least one)',
    'rejectReasonRequired': 'Choose at least one reason.',
    'rejectNote': 'Note for the applicant (optional)',
    'rejectNoteRequired': 'Describe the reason for Other.',
    'rejectReason_card': 'The card photo is unclear or incomplete',
    'rejectReason_selfie': "The selfie doesn't match the card photo",
    'rejectReason_data': "Your details don't match the card",
    'rejectReason_other': 'Other',
    'rejected': '{name} is rejected.',
    'reviewTitle': 'Verification',
    'reviewEmpty': 'No accounts are waiting for review.',
    'reviewLoadFailed': 'Could not load the list.',
    'retry': 'Try again',
    'reviewWaiting': 'Waiting {time}',
    'reviewHours': '{n} h',
    'reviewMinutes': '{n} min',
    'reviewOverdue': 'Over 24 hours',
    'reviewDetailTitle': 'Review files',
    'reviewIdentity': 'Personal details',
    'reviewAccountType': 'Account type',
    'reviewCard': 'Card',
    'reviewCardPhoto': 'Card photo',
    'reviewSelfie': 'Selfie',
    'reviewPhotoFailed': 'Photo could not be loaded.',
    'reviewPhotoMissing': 'No photo.',
    'reviewPhotoDeleted': 'Photo deleted under the 30-day policy.',
    'reviewPhoneMissing': 'No phone number',
    'releasePhone': 'Release phone number',
    'releasePhoneTitle': "Release {name}'s phone number?",
    'releasePhoneBody': 'The number is removed from this account and anyone can register with it. The owner can add a new number later.',
    'releasePhoneNote': 'Note',
    'releasePhoneNoteHelper': "Don't write the phone number in the note.",
    'releasePhoneNoteRequired': 'Write a note.',
    'releasePhoneDone': 'Phone number released.',
    'errorNoteMissing': 'A note is required.',
    'errorNoPhone': 'This account no longer has a phone number.',
    'errorNoteHasPhone': 'Remove the phone number from the note.',
    'errorNoteTooLong': 'Keep the note under 500 characters.',
    'reviewRejections': 'Rejected before ({n})',
    'approve': 'Approve',
    'approveConfirm': 'Approve {name}? They get full access to BeeKas.',
    'cancel': 'Cancel',
    'close': 'Close',
    'help': 'Help',
    'helpNoMailTitle': 'No email app',
    'helpNoMailBody': 'Email us from any email app at this address:',
    'helpCopy': 'Copy address',
    'helpCopied': 'Address copied.',
    'approved': '{name} is approved.',
    // Catalog (#74).
    'tagline': 'Preloved Goods, New Value',
    'searchHint': 'Search items, categories, or sellers...',
    'searchCategoryHint': 'Search categories...',
    'bannerTitle': 'From Binusians,\nFor Binusians',
    'bannerBody': 'Buy, sell, and share items in the BINUS community!',
    'recommended': 'Recommended for You',
    'navHome': 'Home',
    'navCategories': 'Categories',
    'navSell': 'Sell an item',
    'navChat': 'Chat',
    'navProfile': 'Profile',
    'favorites': 'Favorites',
    'notifications': 'Notifications',
    'comingSoon': 'Coming soon',
    'catalogEmpty': 'No items yet.',
    'searchEmpty': 'No items match your search.',
    'catalogError':
        "Couldn't load the catalog. Check your connection and try again.",
    'free': 'Free',
    'donation': 'Donation',
    'verified': 'Verified',
    'condition': 'Condition',
    'warranty': 'Warranty',
    'location': 'Location',
    'stock': 'Stock',
    'stockCount': '{n} left',
    'description': 'Description',
    'specs': 'Specifications',
    'chatSeller': 'Chat Seller',
    'booking24h': 'Book for 24 Hours',
    'buyNow': 'Buy Now',
    'addFavorite': 'Add to favorites',
    'photoCount': 'Photo {i} of {n}',
    'noPhoto': 'No photo',
    'category_laptop_computer': 'Laptops & Computers',
    'category_phone_gadget': 'Phones & Gadgets',
    'category_accessories': 'Accessories',
    'category_clothing': 'Clothing',
    'category_shoes': 'Shoes',
    'category_bags': 'Bags',
    'category_books_stationery': 'Books & Stationery',
    'category_campus_supplies': 'Campus Supplies',
    'category_other': 'Others',
    'group_all': 'All',
    'group_electronics': 'Electronics',
    'group_fashion': 'Fashion',
    'group_books': 'Books',
    'group_supplies': 'Supplies',
    'condition_like_new': 'Like new',
    'condition_used_good': 'Used – good',
    'condition_used_flawed': 'Used – has flaws',
    'errorPhotoUnsupported':
        "This photo format isn't supported yet. Choose a JPEG photo.",
    'errorNoQuota':
        'Your listing quota has run out. Buy a package to list this item.',
    'errorNotAllowedToList': "Your account can't list items right now.",
    'sellTitle': 'Add Item',
    'sellTypeSale': 'Sell Item',
    'sellTypeSaleBody': 'Earn money from things you own',
    'sellTypeDonation': 'Donate Item',
    'sellTypeDonationBody': 'Give your things to those who need them',
    'sellCategory': 'Choose Category',
    'sellCategoryHint': 'Choose a category',
    'sellPhotos': 'Product Photos',
    'sellPhotosHelp': '1–5 photos from the camera or gallery.',
    'sellAddPhoto': 'Add photo',
    'sellRemovePhoto': 'Remove photo {i}',
    'sellCamera': 'Camera',
    'sellCameraDenied': 'BeeKas needs camera access to photograph your item. Allow the camera in Settings, or pick a photo from the gallery.',
    'sellGallery': 'Gallery',
    'sellName': 'Product Name',
    'sellNameHint': 'Macbook Air M1',
    'sellDescriptionHint': 'Describe the condition, specifications, etc...',
    'sellProhibited':
        'Not allowed: alcohol, cigarettes/vapes, food, animals, and medicine.',
    'sellNext': 'Next',
    'sellDetails': 'Item Details',
    'sellConditionHint': 'Choose a condition',
    'sellPrice': 'Price (Rp)',
    'sellPriceHint': '50000',
    'sellWarranty': 'Warranty (optional)',
    'sellWarrantyHint': 'Official warranty until Dec 2026',
    'sellSpecs': 'Specifications (optional)',
    'sellSpecsHelp': 'One per line, up to 10 lines.',
    'sellQuota': 'Listing quota left: {n}. Listing uses 1.',
    'sellQuotaEmpty': 'Your listing quota is 0. Buy a package to list this item; your entries are kept.',
    'sellPost': 'List Item',
    'sellBuyQuota': 'Buy a Quota Package',
    'sellPosted': 'Your item is live.',
    'sellFailed':
        "Couldn't list the item. Check your connection and try again.",
    'sellLoadFailed':
        "Couldn't load your quota. Check your connection and try again.",
    'sellNeedsApproval_guest': 'Sign in with a verified account to sell items.',
    'sellNeedsApproval_incomplete':
        'Finish verifying your account to sell items.',
    'sellNeedsApproval_pending':
        'Your account is being verified. You can sell once it is approved.',
    'sellNeedsApproval_rejected':
        'Your verification was rejected. Resend your photos to sell items.',
    'quotaTitle': 'Listing Quota',
    'profileQuota': 'Quota',
    'quotaLeft': 'Listing quota left: {n}',
    'quotaBuy': 'Buy a Package · {price} = 3 listings',
    'quotaHistory': 'Purchase history',
    'quotaHistoryEmpty': 'No purchases yet.',
    'paymentKind_package': 'Package: 3 listings',
    'paymentKind_boost': 'Boost',
    'paymentKind_featured': 'Featured',
    'paymentStatus_pending': 'Waiting for admin confirmation (max. 1×24 hours)',
    'paymentStatus_confirmed': 'Confirmed',
    'paymentStatus_rejected': 'Rejected',
    'paymentReason': 'Reason: {reason}',
    'paymentReupload': 'Upload Again',
    'qrisTitle': 'Pay with QRIS',
    'qrisAmount': 'Amount to pay',
    'qrisSteps': '1. Scan this QRIS with your bank or e-wallet app.\n2. Pay the exact amount.\n3. Take a screenshot of the payment proof and upload it here.',
    'qrisMissing':
        "Couldn't load the QRIS image. Check your connection and try again.",
    'qrisUpload': 'Upload Payment Proof',
    'qrisSent': 'Proof sent. Waiting for admin confirmation (max. 1×24 hours).',
    'qrisFailed':
        "Couldn't send the proof. Check your connection and try again.",
    'paymentsAdminTitle': 'Payments',
    'paymentsEmpty': 'No payments are waiting.',
    'paymentsLoadFailed': "Couldn't load the payments.",
    'paymentDetailTitle': 'Payment',
    'paymentProof': 'Payment proof',
    'paymentProofFailed': "Couldn't load the proof.",
    'paymentMember': 'Member',
    'paymentKind': 'Type',
    'paymentExpected': 'Amount due',
    'paymentReceived': 'Amount received (Rp)',
    'paymentReceivedInvalid': 'Enter the amount actually received.',
    'paymentConfirm': 'Confirm',
    'paymentRejectTitle': 'Reject the payment from {name}?',
    'paymentRejectReason': 'Reason (the member reads it)',
    'paymentReasonRequired': 'Enter a reason of up to 500 characters.',
    'paymentConfirmed': 'Payment from {name} confirmed.',
    'paymentRejected': 'Payment from {name} rejected.',
    'paymentNotPending': 'Another admin already decided this payment.',
    'errorInvalidAmount': 'The amount received must be above 0.',
    'errorPaymentPending': 'Your last payment is still waiting for admin confirmation. You can buy again once it is confirmed or rejected.',
    'listingError_category': 'Choose a category.',
    'listingError_photos': 'Add 1–5 photos.',
    'listingError_title': 'Enter a name of up to 100 characters.',
    'listingError_description': 'Enter a description of up to 500 characters.',
    'listingError_condition': 'Choose a condition.',
    'listingError_price': 'Enter a price from Rp 1.000 to Rp 50.000.000.',
    'listingError_stock': 'Stock must be at least 1.',
    'listingError_specs': 'Up to 10 lines.',
    'orderNeedsApproval_guest':
        'Sign in with a verified account to book or buy.',
    'orderNeedsApproval_incomplete':
        'Finish verifying your account to book or buy.',
    'orderNeedsApproval_pending': 'Your account is being verified. You can book or buy once it is approved.',
    'orderNeedsApproval_rejected':
        'Your verification was rejected. Send it again to book or buy.',
    'bookingTitle': 'Book Item',
    'bookingIntro': 'You are about to book {title}.',
    'bookingHeld': 'The item will be held for',
    'booking24': '24 Hours',
    'bookingAutoCancel': 'After 24 hours, the booking is cancelled automatically and the item is available to other Binusians again.',
    'bookingNoPayment': 'No payment when booking.',
    'bookingConfirm': 'Book Now',
    'bookingStatusTitle': 'Booking Status',
    'bookingDone': 'Booked!',
    'bookingDoneBody': 'The item is held for 24 hours.',
    'holdLeftTitle': 'Booking time left',
    'hours': 'Hours',
    'minutes': 'Minutes',
    'seconds': 'Seconds',
    'holdWarning':
        'When time runs out, the booking is cancelled automatically.',
    'checkoutTitle': 'Checkout',
    'codLocation': 'COD Location',
    'change': 'Change',
    'codPlace': 'Meeting point (optional)',
    'codPlaceHint': 'e.g. Anggrek lobby, by the ATM',
    'save': 'Save',
    'paymentMethod': 'Payment Method',
    'codMethod': 'COD on campus',
    'codMethodBody': 'Pay in cash when you meet the seller on campus.',
    'orderSummary': 'Order Summary',
    'orderQty': 'qty: {n}',
    'subtotal': 'Subtotal',
    'total': 'Total',
    'checkoutCodOnly': 'Payment is only made in person at the COD on campus.',
    'checkoutConfirm': 'Confirm Order',
    'ordersTitle': 'My Orders',
    'ordersPurchases': 'Purchases',
    'ordersSales': 'Sales',
    'orderFilter_all': 'All',
    'orderFilter_waiting': 'Waiting',
    'orderFilter_processing': 'Processing',
    'orderFilter_completed': 'Completed',
    'orderFilter_cancelled': 'Cancelled',
    'orderStatus_waiting': 'Waiting for seller confirmation',
    'orderStatus_processing': 'Processing',
    'orderStatus_completed': 'Completed',
    'orderStatus_cancelled': 'Cancelled',
    'holdLeft': '{time} left',
    'ordersEmpty': 'No orders here yet.',
    'ordersLoadFailed':
        "Couldn't load your orders. Check your connection and try again.",
    'orderDetailTitle': 'Order Details',
    'orderKind': 'Type',
    'orderKind_booking': 'Booking (24 hours)',
    'orderKind_buy': 'Buy Now',
    'orderStatus': 'Status',
    'orderPrice': 'Price',
    'orderSeller': 'Seller',
    'orderBuyer': 'Buyer',
    'codTime': 'COD time',
    'codTimeUnset': 'Set by the seller when accepting.',
    'autoCompleteNote': 'Completed automatically 3 days after the COD time unless the buyer confirms earlier.',
    'extensionRequested': 'The buyer asked for 24 more hours.',
    'cancelledAuto': 'Cancelled automatically: not accepted in time.',
    'cancelledReason': 'Reason: {reason}',
    'orderAction_accept': 'Accept',
    'orderAction_reject': 'Reject',
    'orderAction_cancel': 'Cancel order',
    'orderAction_complete': 'Item received',
    'orderAction_requestExtension': 'Ask for 24 more hours',
    'orderAction_approveExtension': 'Approve 24 more hours',
    'orderAction_updateLocation': 'Change COD location',
    'orderAction_updateCodTime': 'Change COD time',
    'cancelTitle': 'Cancel this order?',
    'cancelReason_changed_mind': 'Changed my mind',
    'cancelReason_not_as_described': 'Item not as described',
    'cancelReason_cannot_meet': "Can't meet",
    'cancelReason_sold_elsewhere': 'Sold elsewhere',
    'cancelReason_other': 'Other',
    'cancelNote': 'Note',
    'cancelReasonRequired':
        'Choose a reason. For Other, write a note (up to 500 characters).',
    'cancelOrder': 'Yes, cancel',
    'orderUpdated': 'Order updated.',
    'errorListingUnavailable': 'This item is no longer available.',
    'errorOwnListing': "You can't order your own item.",
    'errorSoldOut': 'Someone else just took the last unit.',
    'errorAlreadyOrdered': 'You already have a running order for this item.',
    'errorDonationLimit': 'You already have 2 running donation orders. Finish or cancel one first.',
    'errorOrderTransition':
        'This order changed in the meantime. Its current status is shown.',
    'errorNotParty': "You're not part of this order.",
    'errorCodTimeMissing': 'Set the COD time.',
    'errorCodTimePast': 'Choose a COD time from now on.',
    'codPlaceTooLong': 'Up to 200 characters.',
  },
  Lang.id: {
    'back': 'Kembali',
    'showPassword': 'Tampilkan kata sandi',
    'hidePassword': 'Sembunyikan kata sandi',
    'signIn': 'Masuk',
    'register': 'Daftar',
    'next': 'Lanjut',
    'forgotPassword': 'Lupa kata sandi?',
    'password': 'Kata sandi',
    'fullName': 'Nama lengkap',
    'fullNameHint': 'John Doe',
    'fullNameRequired': 'Isi nama lengkap.',
    'registerDataWarning':
        'Pastikan data sudah benar dan sesuai identitas BINUS.',
    'errorInvalidEmailDomain':
        'Gunakan email BINUS (@binus.ac.id atau @binus.edu).',
    'errorAccountTypeNotAllowed':
        'Tipe akun untuk @binus.ac.id ditentukan otomatis.',
    'errorAccountTypeRequired': 'Pilih Dosen atau Staf.',
    'errorInvalidCampus': 'Pilih kampus asal.',
    'errorPhoneRequired': 'Isi nomor HP.',
    'errorInvalidPhone': 'Masukkan nomor HP yang valid.',
    'errorPhoneTaken':
        'Nomor ini tidak bisa dipakai. Coba nomor lain atau lewati.',
    'errorSignupUnknown': 'Pendaftaran gagal. Coba lagi.',
    'registerTitle': 'Isi Data Diri',
    'registerSubtitle':
        'Lengkapi informasi berikut untuk melanjutkan pendaftaran.',
    'registerStep': 'Langkah {n} dari 3',
    'emailBinus': 'Email BINUS',
    'emailHint': 'john.doe@binus.ac.id',
    'phone': 'Nomor Handphone',
    'phoneHint': '+62 812 3456 7890',
    'phoneOptional': 'Nomor Handphone (opsional)',
    'phoneHelper': 'Opsional. Hanya dipakai tim BeeKas bila perlu menghubungimu, tidak ditampilkan ke pengguna lain.',
    'accountType': 'Tipe Akun',
    'accountTypeHint': 'Pilih Dosen atau Staf',
    'accountType_student': 'Mahasiswa',
    'accountType_lecturer': 'Dosen',
    'accountType_staff': 'Staf',
    'campus': 'Kampus Asal',
    'campusHint': 'Pilih kampus asal',
    'campus_kemanggisan': 'Kampus Binus Kemanggisan',
    'campus_senayan': 'Kampus Binus Senayan',
    'campus_alam_sutera': 'Kampus Binus Alam Sutera',
    'campus_base': 'Kampus Binus BASE',
    'campus_bekasi': 'Kampus Binus Bekasi',
    'campus_bandung': 'Kampus Binus Bandung',
    'campus_malang': 'Kampus Binus Malang',
    'campus_semarang': 'Kampus Binus Semarang',
    'campus_online': 'BINUS Online',
    'errorEmailRequired': 'Isi email BINUS.',
    'errorNetwork':
        'Tidak bisa terhubung ke server. Periksa koneksi lalu coba lagi.',
    'codeSent': 'Kode 6 digit sudah dikirim ke email kamu.',
    'errorInvalidCode': 'Kode salah atau sudah kedaluwarsa.',
    'errorTooSoon': 'Tunggu sebentar sebelum meminta kode baru.',
    'errorWeakPassword': 'Kata sandi belum memenuhi syarat.',
    'otpTitle': 'Verifikasi Email',
    'otpSubtitle': 'Masukkan kode 6 digit yang dikirim ke {email}.',
    'otpCode': 'Kode verifikasi',
    'otpHint': '123456',
    'errorCodeRequired': 'Isi kode 6 digit.',
    'verify': 'Verifikasi',
    'resendCode': 'Kirim ulang kode',
    'resendIn': 'Kirim ulang dalam {s} dtk',
    'emailRegistered': 'Email ini sudah terdaftar. Silakan masuk.',
    'phoneTitle': 'Nomor Handphone',
    'phoneSubtitle':
        'Nomor HP kamu belum tersimpan. Masukkan nomor lain atau lewati.',
    'skip': 'Lewati',
    'phoneKept': 'Nomor HP {phone} dari pendaftaran sebelumnya tetap dipakai, bukan nomor yang baru diisi.',
    'passwordTitle': 'Buat Kata Sandi',
    'passwordSubtitle': 'Kata sandi ini dipakai untuk masuk ke BeeKas.',
    'passwordConfirm': 'Konfirmasi kata sandi',
    'passwordHelper': 'Jangan gunakan kata sandi Binusmaya atau akun lain. Buat kata sandi khusus untuk BeeKas.',
    'ruleMinLength': 'Minimal 8 karakter',
    'ruleLetter': 'Ada huruf',
    'ruleDigit': 'Ada angka',
    'ruleMatch': 'Sama dengan konfirmasi',
    'passwordSaved': 'Kata sandi tersimpan.',
    'consentTitle': 'Persetujuan Data',
    'consentSubtitle':
        'Sebelum mengambil foto, baca cara BeeKas memperlakukan datamu.',
    'consentDataLabel': 'Data yang diambil',
    'consentData': 'Foto kartu identitas dan foto wajah.',
    'consentPurposeLabel': 'Tujuan',
    'consentPurpose': 'Memastikan pemilik akun adalah warga BINUS.',
    'consentViewerLabel': 'Yang melihat',
    'consentViewer': 'Hanya admin BeeKas.',
    'consentRetentionLabel': 'Masa simpan',
    'consentRetention': 'Dihapus paling lambat 30 hari setelah diperiksa.',
    'consentAgree': 'Saya setuju BeeKas mengolah foto kartu dan foto wajah saya seperti dijelaskan di atas.',
    'card_student': 'kartu Flazz',
    'card_lecturer': 'ID card dosen',
    'card_staff': 'ID card staf',
    'cardTitle': 'Verifikasi Identitas BINUS',
    'cardSubtitle': 'Foto {card} kamu untuk verifikasi akun. Pastikan foto terlihat jelas dan tidak buram.',
    'cardTake': 'Ambil foto {card}',
    'cardFormat': 'Format: JPG/PNG • Maks. 5 MB',
    'tipLight': 'Cahaya cukup, tanpa pantulan',
    'tipSharp': 'Foto tidak buram',
    'tipReadable': 'Nama dan data terbaca',
    'takePhoto': 'Ambil foto',
    'errorCameraDenied': 'BeeKas butuh izin kamera untuk mengambil foto verifikasi. Izinkan kamera di Pengaturan.',
    'openSettings': 'Buka Pengaturan',
    'errorPhotoTooLarge': 'Foto lebih dari 5 MB. Ambil ulang.',
    'errorPhotoFailed': 'Foto gagal diambil. Coba lagi.',
    'cardConfirmTitle': 'Konfirmasi Foto Kartu',
    'cardConfirmSubtitle': 'Pastikan foto {card} kamu sudah sesuai dan jelas.',
    'cardPreview': 'Foto {card} kamu',
    'checkClear': 'Kartu terlihat jelas',
    'checkMatches': 'Data sesuai dengan akun',
    'checkNoGlare': 'Tidak buram, tanpa pantulan',
    'retake': 'Ulangi',
    'usePhoto': 'Gunakan foto',
    'selfieTitle': 'Verifikasi Wajah',
    'selfieSubtitle':
        'Lakukan foto selfie untuk mencocokkan dengan foto di {card} kamu.',
    'tipFaceLight': 'Gunakan pencahayaan yang cukup',
    'tipFaceClear': 'Pastikan wajah terlihat jelas dan tidak tertutup. Hijab atau kerudung boleh dipakai.',
    'tipFaceCover':
        'Jangan memakai kacamata, topi, masker, atau penutup wajah lain',
    'tipFaceClothes': 'Gunakan pakaian yang sopan',
    'startVerification': 'Mulai Verifikasi',
    'selfiePreview': 'Selfie kamu',
    'send': 'Kirim',
    'errorSendFailed': 'Foto gagal dikirim. Coba lagi.',
    'errorPhotosMissing': 'Foto belum sampai. Ketuk Kirim untuk mencoba lagi.',
    'errorAlreadyApproved':
        'Akunmu sudah terverifikasi. Masuk ulang untuk melanjutkan.',
    'errorStatusRejected': 'Kiriman sebelumnya ditolak. Masuk ulang untuk melihat alasannya dan kirim ulang.',
    'errorStatusIncomplete':
        'Foto belum terkirim. Ketuk Kirim untuk mencoba lagi.',
    'pendingTitle': 'Verifikasi Sedang Diproses',
    'pendingBody': 'Data kamu telah kami terima. Tim BeeKas akan memverifikasi dalam 1×24 jam. Kamu akan mendapatkan notifikasi setelah proses selesai.',
    'pendingTipsTitle': 'Tips:',
    'pendingTipData': 'Pastikan data yang kamu masukkan benar',
    'pendingTipPhoto': 'Gunakan foto yang jelas dan tidak blur',
    'pendingTipHelp': 'Jika dalam 1×24 jam belum ada update, kamu bisa menghubungi kami melalui fitur Bantuan.',
    'browseCatalog': 'Lihat katalog',
    'signOut': 'Keluar',
    'errorInvalidCredentials': 'Email atau kata sandi salah.',
    'errorRateLimited':
        'Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi.',
    'errorSignInFailed': 'Gagal masuk. Silakan coba lagi.',
    'onboardingTagline': 'Jual, Beli, Berbagi di BINUS',
    'onboardingCommunity': 'Untuk Komunitas',
    'onboardingRegister': 'Daftar Akun Baru',
    'languageLabel': 'Bahasa: {name}',
    'onboarding1Body': 'BeeKas adalah marketplace barang preloved khusus komunitas BINUS. Jual dan beli barang bekas dengan aman, sesama Binusian.',
    'onboarding2Pre': 'Cari Barang ',
    'onboarding2Mark': 'Tanpa',
    'onboarding2Post': ' Ribet',
    'onboarding2Body': 'Semua barang tersusun rapi dalam katalog. Nggak perlu scrolling media sosial lagi buat nemuin barang preloved yang kamu cari.',
    'onboarding3Pre': 'Transaksi Lebih ',
    'onboarding3Mark': 'Terpercaya',
    'onboarding3Post': '',
    'onboarding3Body': 'Setiap barang punya status Tersedia, di Booking, atau Terjual. Penjual juga dilengkapi nama, status (Mahasiswa/Dosen/Staff), dan kampus.',
    'onboarding4Pre': 'Siap ',
    'onboarding4Mark': 'Jual Beli',
    'onboarding4Post': ' di Kampus?',
    // D-22 point 2: chat in the app, not WhatsApp.
    'onboarding4Body': 'Foto barangmu, pasang dalam hitungan menit, lalu ngobrol dengan pembeli lewat chat BeeKas dan ketemuan COD di kampus.',
    'signInTitle': 'Selamat Datang di ',
    'signInTitleEnd': '!',
    'signInSubtitle': 'Masuk untuk melanjutkan ke marketplace komunitas BINUS.',
    'email': 'Email',
    'emailRequired': 'Masukkan email kamu.',
    'passwordRequired': 'Masukkan kata sandi kamu.',
    'noAccount': 'Belum punya akun?',
    'browseAsGuest': 'Lihat katalog sebagai tamu',
    'legalReminder': 'Dengan masuk atau mendaftar, kamu menyetujui',
    'and': 'dan',
    'terms': 'Syarat & Ketentuan',
    'privacy': 'Kebijakan Privasi',
    'legalReadMore': 'Baca selengkapnya di',
    'legalDraftMarker': '[DRAF — menunggu tim]',
    // From notes/kebijakan-privasi-sk-draf.md (draf 0.1); tables as lists.
    'privacyBody': '''Versi draf 0.1. Berlaku sejak [tanggal rilis].

BeeKas mengumpulkan data seperlunya untuk memastikan setiap pengguna adalah warga BINUS, lalu memakainya hanya untuk menjalankan marketplace. Kami tidak menjual data dan tidak memakainya untuk iklan.

# 1. Siapa kami

BeeKas adalah marketplace jual, beli, dan donasi barang bekas untuk komunitas BINUS, dibuat oleh tim mahasiswa dalam mata kuliah Venture Creation (ENPR6312001). BeeKas bukan layanan resmi Universitas Bina Nusantara.

Penanggung jawab data pribadi adalah CTO BeeKas. Hubungi kami di beekas2026@gmail.com.

# 2. Data yang kami kumpulkan

Untuk setiap data: kapan diambil, wajib atau tidak, dan untuk apa.

- Nama lengkap, email BINUS, tipe akun (mahasiswa/dosen/staf), kampus — saat daftar, wajib. Membuat akun dan memeriksa identitas.

- Nomor HP — saat daftar, opsional. Hanya dipakai tim BeeKas bila perlu menghubungimu, tidak ditampilkan ke pengguna lain.

- Kata sandi — saat daftar, wajib. Masuk ke akun. Disimpan dalam bentuk hash; tim tidak bisa melihatnya.

- Foto kartu identitas BINUS dan foto wajah (selfie) — verifikasi identitas, wajib untuk akses penuh. Admin mencocokkan wajah dan data di kartu dengan data pendaftaran.

- Bukti persetujuan (waktu dan versi teks) — saat menyetujui, wajib. Bukti bahwa kamu menyetujui pemakaian foto.

- Riwayat verifikasi (status, admin pemeriksa, waktu, alasan penolakan, catatan) — setelah diperiksa, otomatis. Jejak pemeriksaan dan penanganan keluhan.

- Angkatan (BINUSIAN) — Edit Profil, opsional. Ditampilkan di profil; tidak diverifikasi.

- Barang yang kamu pasang (foto, judul, deskripsi, harga, kategori, kondisi) — saat memasang barang, wajib untuk memasang. Ditampilkan di katalog.

- Isi chat — saat chat, otomatis. Menyepakati transaksi dan COD.

- Booking, pesanan, lokasi dan waktu COD — saat bertransaksi, otomatis. Menjalankan booking 24 jam dan pesanan.

- Ulasan, rating, dan daftar akun yang kamu ikuti — saat kamu memberi atau mengikuti, opsional. Ditampilkan di profil dan barang.

- Pembelian kuota listing [KONFIRMASI: data apa yang disimpan, mis. bukti transfer QRIS] — saat membeli kuota, wajib untuk membeli. Konfirmasi pembayaran oleh admin.

Data yang tersimpan hanya di perangkatmu: pilihan bahasa, status onboarding, dan sesi masuk.

Yang tidak kami kumpulkan: NIM, jurusan, dan lokasi GPS. Data lokasi di dalam foto verifikasi dibuang sebelum diunggah. [KONFIRMASI: berlaku juga untuk foto barang.]

# 3. Siapa yang bisa melihat datamu

- Foto kartu dan selfie: hanya admin, yaitu lima anggota tim BeeKas dengan akun masing-masing.

- Nomor HP: kamu dan admin.

- Email BINUS: kamu dan admin. [KONFIRMASI: tidak ditampilkan ke pengguna lain]

- Nama, kampus, tipe akun, tanda terverifikasi, barang, ulasan: pengguna lain dan tamu yang membuka katalog. [KONFIRMASI: apa saja yang tampil ke tamu]

- Isi chat: kamu dan lawan chat. [KONFIRMASI: apakah admin boleh membaca chat saat ada laporan]

- Riwayat verifikasi: kamu (riwayatmu sendiri) dan admin.

# 4. Pihak lain yang memproses data

- Supabase: database, autentikasi, dan penyimpanan foto. [KONFIRMASI: lokasi server. Bila di luar Indonesia, pengiriman data ke luar negeri harus memenuhi ketentuan UU PDP.]

- Penyedia email: mengirim kode OTP dan email hasil verifikasi. [KONFIRMASI: penyedia belum dipilih.]

- Gmail: menerima email Bantuan yang kamu kirim ke beekas2026@gmail.com.

- Bila nanti ada notifikasi push atau pembuatan listing dengan AI, penyedianya ditambahkan di sini sebelum fitur itu dipakai.

Kami tidak menjual atau menyewakan data ke pihak mana pun.

# 5. Berapa lama data disimpan

- Foto kartu dan selfie: dihapus paling lambat 30 hari setelah verifikasi disetujui atau ditolak.

- Riwayat verifikasi: tetap disimpan setelah foto dihapus, selama akun ada. [KONFIRMASI: berapa lama setelah akun dihapus.]

- Data akun, barang, chat, dan ulasan: selama akun aktif. [KONFIRMASI: batas waktu penghapusan setelah akun ditutup.]

- Bila BeeKas dialihkan ke pihak lain, termasuk BINUS, kami memberi tahu pengguna sebelum data dialihkan.

# 6. Cara kami menjaga data

- Foto verifikasi disimpan di penyimpanan privat yang tidak bisa diakses publik.

- Aturan akses di database membatasi siapa membaca apa, bukan hanya tampilan aplikasi.

- Setiap admin punya akun sendiri, sehingga setiap persetujuan dan penolakan tercatat atas nama admin yang memeriksa.

# 7. Hak kamu

Sesuai UU Pelindungan Data Pribadi (UU No. 27 Tahun 2022), kamu bisa meminta:

- salinan data pribadimu;

- perbaikan data yang salah;

- penghapusan akun dan data pribadimu;

- penarikan persetujuan pemakaian foto verifikasi. Akibatnya, akses penuh dicabut sampai kamu memverifikasi ulang. [KONFIRMASI: alur penarikan belum dibangun.]

Kirim permintaan ke beekas2026@gmail.com dari email BINUS-mu. Kami menjawab dalam [KONFIRMASI: batas waktu; perlu dicek terhadap UU PDP].

# 8. Bila terjadi kebocoran data

Kami memberi tahu pengguna yang terdampak secara tertulis, berisi data apa yang terdampak, kapan, dan langkah yang kami ambil. [KONFIRMASI: batas waktu pemberitahuan menurut UU PDP.]

# 9. Pengguna di bawah 18 tahun

[KONFIRMASI: sebagian mahasiswa baru mungkin belum 18 tahun. UU PDP mewajibkan persetujuan orang tua atau wali untuk data anak. Tim perlu memutuskan apakah membatasi usia atau menambah langkah persetujuan.]

# 10. Perubahan kebijakan

Perubahan diumumkan di aplikasi. Bila pemakaian foto verifikasi berubah, kamu diminta menyetujui ulang sebelum melanjutkan.''',
    'termsBody': '''Versi draf 0.1. Berlaku sejak [tanggal rilis].

Dengan mendaftar atau memakai BeeKas, kamu menyetujui syarat ini. BeeKas mempertemukan penjual dan pembeli di komunitas BINUS; transaksi dan pembayaran terjadi langsung di antara kalian saat COD di kampus.

# 1. Siapa yang boleh memakai BeeKas

- Tamu tanpa akun boleh melihat katalog.

- Akun hanya untuk pemilik email BINUS aktif (@binus.ac.id atau @binus.edu). Alumni yang email @binus.ac.id-nya masih aktif mendaftar sebagai mahasiswa.

- Satu orang, satu akun. Akun tidak boleh dipinjamkan, dijual, atau dipakai orang lain.

- [KONFIRMASI: batas usia minimum, lihat Kebijakan Privasi bagian 9.]

# 2. Akun dan verifikasi

- Data pendaftaran harus benar dan sesuai kartu identitas BINUS-mu.

- Akses penuh (menghubungi penjual, membeli, memasang barang) baru terbuka setelah tim memverifikasi foto kartu dan selfie-mu. Pemeriksaan selesai paling lambat 1×24 jam, termasuk akhir pekan dan hari libur.

- Bila ditolak, kamu melihat alasannya dan boleh mengirim ulang foto. Belum ada batas jumlah pengiriman ulang.

- Buat kata sandi khusus untuk BeeKas. Jangan pakai kata sandi Binusmaya atau akun lain.

- Kamu bertanggung jawab atas semua aktivitas di akunmu. Bila curiga akunmu dipakai orang lain, segera hubungi Bantuan.

# 3. Memasang barang

- Kamu bisa menjual barang atau mendonasikannya. Barang donasi diberikan gratis kepada pembeli.

- Biaya: Rp1.000 per listing, termasuk listing donasi. Biaya dibayar lewat paket kuota listing prabayar ke QRIS tim BeeKas, lalu dikonfirmasi admin. [KONFIRMASI: harga paket, masa berlaku kuota, dan apakah kuota bisa dikembalikan.]

- Foto harus foto asli barang yang dijual. Deskripsi dan kondisi harus jujur, termasuk cacat atau kerusakan.

- Harga coret hanya boleh dipakai bila sesuai harga yang benar-benar pernah berlaku. Harga asli palsu dilarang.

- Hapus atau tandai terjual barang yang sudah tidak tersedia.

# 4. Barang yang dilarang

- Barang ilegal, narkotika, obat keras, dan obat tanpa izin edar.

- Senjata, bahan peledak, dan barang berbahaya.

- Barang curian, palsu, atau bajakan, termasuk software dan buku bajakan.

- Kartu identitas, Flazz, atau dokumen milik siapa pun.

- Akun digital, voucher yang dilarang dijual ulang, dan jasa joki tugas atau ujian.

- Konten dewasa.

- [KONFIRMASI: alkohol, rokok dan vape, makanan, hewan, serta obat bebas.]

# 5. Booking, pembelian, dan COD

- Booking 24 Jam: barang ditahan untukmu selama 24 jam tanpa pembayaran. Setelah 24 jam tanpa kelanjutan, booking batal otomatis dan barang tersedia lagi. [KONFIRMASI: apakah penjual boleh memperpanjang.]

- Beli Sekarang: kamu mengonfirmasi pesanan, lalu penjual memprosesnya.

- COD di kampus: lokasi dan waktu disepakati lewat chat di aplikasi. Bayar langsung ke penjual saat bertemu. Tidak ada pengiriman.

- Periksa barang sebelum membayar. Pilih tempat ramai di area kampus.

- BeeKas tidak memegang uang transaksi dan bukan pihak dalam jual beli. Sengketa diselesaikan antara penjual dan pembeli; tim bisa membantu menengahi lewat Bantuan.

# 6. Chat, ulasan, dan perilaku

- Bersikap sopan. Pelecehan, ancaman, ujaran kebencian, dan spam dilarang.

- Jangan menyebarkan data pribadi orang lain, termasuk foto atau nomor HP, tanpa izinnya.

- Ulasan harus jujur dan berdasarkan transaksi yang benar-benar terjadi. [KONFIRMASI: ulasan hanya setelah pesanan selesai.]

- Jangan memakai BeeKas untuk menipu atau mengalihkan transaksi ke luar aplikasi demi menghindari aturan ini.

# 7. Pelanggaran

Tim BeeKas boleh menghapus listing, membatasi fitur, atau menutup akun yang melanggar syarat ini. Laporkan pelanggaran lewat Bantuan (beekas2026@gmail.com). [KONFIRMASI: fitur lapor dan blokir di aplikasi.]

# 8. Batas tanggung jawab

BeeKas adalah proyek mahasiswa dan disediakan sebagaimana adanya. Kami berusaha menjaga aplikasi tetap berjalan dan aman, tetapi tidak menjamin kualitas barang, kejujuran pengguna, atau hasil transaksi. Verifikasi identitas memastikan pengguna adalah warga BINUS, bukan menjamin perilakunya.

# 9. Perubahan dan hukum yang berlaku

Perubahan syarat diumumkan di aplikasi. Syarat ini tunduk pada hukum Republik Indonesia.''',
    'rejectedTitle': 'Verifikasi ditolak',
    'rejectedBody': 'Berkas kamu belum disetujui karena:',
    'rejectedNote': 'Catatan dari tim',
    'rejectedResendHint': 'Kirim foto kartu dan selfie baru. Data diri kamu tidak perlu diisi ulang.',
    'resendVerification': 'Kirim ulang',
    'resetTitle': 'Lupa kata sandi',
    'resetSubtitle': 'Masukkan email BINUS kamu. Kami kirim kode untuk membuat kata sandi baru.',
    'sendCode': 'Kirim kode',
    'resetCodeTitle': 'Masukkan kode',
    'resetCodeSubtitle': 'Masukkan kode 6 digit untuk {email}.',
    'resetCodeSent': 'Jika email terdaftar, kode sudah dikirim.',
    'resetPasswordTitle': 'Kata sandi baru',
    'savePassword': 'Simpan kata sandi',
    'errorResetFailed': 'Gagal mengganti kata sandi. Silakan coba lagi.',
    'errorNotPending': 'Akun ini sudah tidak menunggu pemeriksaan.',
    'errorNotAdmin': 'Hanya admin yang bisa memeriksa verifikasi.',
    'errorReasonMissing': 'Alasan wajib diisi untuk menolak.',
    'reject': 'Tolak',
    'rejectTitle': 'Tolak {name}?',
    'rejectReasons': 'Alasan (pilih minimal satu)',
    'rejectReasonRequired': 'Pilih minimal satu alasan.',
    'rejectNote': 'Catatan untuk pendaftar (opsional)',
    'rejectNoteRequired': 'Jelaskan alasan untuk Lainnya.',
    'rejectReason_card': 'Foto kartu tidak jelas atau tidak lengkap',
    'rejectReason_selfie': 'Selfie tidak cocok dengan foto di kartu',
    'rejectReason_data': 'Data diri tidak sesuai dengan kartu',
    'rejectReason_other': 'Lainnya',
    'rejected': '{name} ditolak.',
    'reviewTitle': 'Verifikasi',
    'reviewEmpty': 'Tidak ada akun yang menunggu pemeriksaan.',
    'reviewLoadFailed': 'Daftar gagal dimuat.',
    'retry': 'Coba lagi',
    'reviewWaiting': 'Menunggu {time}',
    'reviewHours': '{n} jam',
    'reviewMinutes': '{n} menit',
    'reviewOverdue': 'Lewat 24 jam',
    'reviewDetailTitle': 'Periksa berkas',
    'reviewIdentity': 'Data diri',
    'reviewAccountType': 'Tipe akun',
    'reviewCard': 'Kartu',
    'reviewCardPhoto': 'Foto kartu',
    'reviewSelfie': 'Selfie',
    'reviewPhotoFailed': 'Foto gagal dimuat.',
    'reviewPhotoMissing': 'Tidak ada foto.',
    'reviewPhotoDeleted': 'Foto sudah dihapus sesuai kebijakan 30 hari.',
    'reviewPhoneMissing': 'Belum ada nomor HP',
    'releasePhone': 'Lepas nomor HP',
    'releasePhoneTitle': 'Lepas nomor HP {name}?',
    'releasePhoneBody': 'Nomor dihapus dari akun ini dan bisa dipakai pendaftar lain. Pemilik akun bisa menambah nomor lagi nanti.',
    'releasePhoneNote': 'Catatan',
    'releasePhoneNoteHelper': 'Jangan tulis nomor HP di catatan.',
    'releasePhoneNoteRequired': 'Tulis catatan.',
    'releasePhoneDone': 'Nomor HP dilepas.',
    'errorNoteMissing': 'Catatan wajib diisi.',
    'errorNoPhone': 'Akun ini sudah tidak punya nomor HP.',
    'errorNoteHasPhone': 'Hapus nomor HP dari catatan.',
    'errorNoteTooLong': 'Catatan maksimal 500 karakter.',
    'reviewRejections': 'Pernah ditolak ({n})',
    'approve': 'Setujui',
    'approveConfirm':
        'Setujui {name}? Akun ini akan mendapat akses penuh ke BeeKas.',
    'cancel': 'Batal',
    'close': 'Tutup',
    'help': 'Bantuan',
    'helpNoMailTitle': 'Tidak ada aplikasi email',
    'helpNoMailBody': 'Kirim email dari aplikasi email apa pun ke alamat ini:',
    'helpCopy': 'Salin alamat',
    'helpCopied': 'Alamat disalin.',
    'approved': '{name} disetujui.',
    // Katalog (#74).
    'tagline': 'Barang Bekas, Nilai Baru',
    'searchHint': 'Cari produk, kategori, atau nama seller...',
    'searchCategoryHint': 'Cari kategori...',
    'bannerTitle': 'Dari Binusian,\nUntuk Binusian',
    'bannerBody': 'Jual, beli, dan berbagi barang di komunitas BINUS!',
    'recommended': 'Rekomendasi untuk Kamu',
    'navHome': 'Beranda',
    'navCategories': 'Kategori',
    'navSell': 'Jual barang',
    'navChat': 'Chat',
    'navProfile': 'Profil',
    'favorites': 'Favorit',
    'notifications': 'Notifikasi',
    'comingSoon': 'Segera hadir',
    'catalogEmpty': 'Belum ada barang.',
    'searchEmpty': 'Tidak ada barang yang cocok.',
    'catalogError': 'Katalog gagal dimuat. Periksa koneksi lalu coba lagi.',
    'free': 'Gratis',
    'donation': 'Donasi',
    'verified': 'Terverifikasi',
    'condition': 'Kondisi',
    'warranty': 'Garansi',
    'location': 'Lokasi',
    'stock': 'Stok',
    'stockCount': 'Sisa {n}',
    'description': 'Deskripsi',
    'specs': 'Spesifikasi',
    'chatSeller': 'Chat Penjual',
    'booking24h': 'Booking 24 Jam',
    'buyNow': 'Beli Sekarang',
    'addFavorite': 'Tambah ke favorit',
    'photoCount': 'Foto {i} dari {n}',
    'noPhoto': 'Tidak ada foto',
    'category_laptop_computer': 'Laptop & Komputer',
    'category_phone_gadget': 'HP & Gadget',
    'category_accessories': 'Aksesoris',
    'category_clothing': 'Pakaian',
    'category_shoes': 'Sepatu',
    'category_bags': 'Tas',
    'category_books_stationery': 'Buku & Alat Tulis',
    'category_campus_supplies': 'Perlengkapan Kampus',
    'category_other': 'Lainnya',
    'group_all': 'Semua',
    'group_electronics': 'Elektronik',
    'group_fashion': 'Fashion',
    'group_books': 'Buku',
    'group_supplies': 'Perlengkapan',
    'condition_like_new': 'Seperti baru',
    'condition_used_good': 'Bekas – baik',
    'condition_used_flawed': 'Bekas – ada cacat',
    'errorPhotoUnsupported': 'Format foto ini belum didukung. Pilih foto JPEG.',
    'errorNoQuota':
        'Kuota listing habis. Beli paket untuk memasang barang ini.',
    'errorNotAllowedToList': 'Akunmu belum bisa memasang barang saat ini.',
    'sellTitle': 'Tambah Barang',
    'sellTypeSale': 'Jual Barang',
    'sellTypeSaleBody': 'Dapatkan uang dari barang yang kamu punya',
    'sellTypeDonation': 'Donasi Barang',
    'sellTypeDonationBody': 'Berikan barangmu untuk yang membutuhkan',
    'sellCategory': 'Pilih Kategori',
    'sellCategoryHint': 'Pilih kategori',
    'sellPhotos': 'Foto Produk',
    'sellPhotosHelp': '1–5 foto dari kamera atau galeri.',
    'sellAddPhoto': 'Tambah foto',
    'sellRemovePhoto': 'Hapus foto {i}',
    'sellCamera': 'Kamera',
    'sellCameraDenied': 'BeeKas butuh izin kamera untuk memotret barangmu. Izinkan kamera di Pengaturan, atau pilih foto dari galeri.',
    'sellGallery': 'Galeri',
    'sellName': 'Nama Produk',
    'sellNameHint': 'Macbook Air M1',
    'sellDescriptionHint': 'Ceritakan kondisi barang, spesifikasi, dll...',
    'sellProhibited':
        'Dilarang: alkohol, rokok/vape, makanan, hewan, dan obat.',
    'sellNext': 'Lanjut',
    'sellDetails': 'Detail Barang',
    'sellConditionHint': 'Pilih kondisi',
    'sellPrice': 'Harga (Rp)',
    'sellPriceHint': '50000',
    'sellWarranty': 'Garansi (opsional)',
    'sellWarrantyHint': 'Garansi resmi sampai Des 2026',
    'sellSpecs': 'Spesifikasi (opsional)',
    'sellSpecsHelp': 'Satu per baris, maksimal 10 baris.',
    'sellQuota': 'Sisa kuota listing: {n}. Memasang memakai 1.',
    'sellQuotaEmpty': 'Kuota listing-mu 0. Beli paket untuk memasang barang ini; isianmu tetap tersimpan.',
    'sellPost': 'Pasang',
    'sellBuyQuota': 'Beli Paket Kuota',
    'sellPosted': 'Barangmu sudah tayang.',
    'sellFailed': 'Barang gagal dipasang. Periksa koneksi lalu coba lagi.',
    'sellLoadFailed': 'Kuota gagal dimuat. Periksa koneksi lalu coba lagi.',
    'sellNeedsApproval_guest':
        'Masuk dengan akun terverifikasi untuk menjual barang.',
    'sellNeedsApproval_incomplete':
        'Selesaikan verifikasi akun untuk menjual barang.',
    'sellNeedsApproval_pending':
        'Akunmu sedang diverifikasi. Kamu bisa menjual setelah disetujui.',
    'sellNeedsApproval_rejected':
        'Verifikasi akunmu ditolak. Kirim ulang foto untuk menjual barang.',
    'quotaTitle': 'Kuota Listing',
    'profileQuota': 'Kuota',
    'quotaLeft': 'Sisa kuota listing: {n}',
    'quotaBuy': 'Beli Paket · {price} = 3 listing',
    'quotaHistory': 'Riwayat pembelian',
    'quotaHistoryEmpty': 'Belum ada pembelian.',
    'paymentKind_package': 'Paket 3 listing',
    'paymentKind_boost': 'Boost',
    'paymentKind_featured': 'Featured',
    'paymentStatus_pending': 'Menunggu konfirmasi admin (maks. 1×24 jam)',
    'paymentStatus_confirmed': 'Dikonfirmasi',
    'paymentStatus_rejected': 'Ditolak',
    'paymentReason': 'Alasan: {reason}',
    'paymentReupload': 'Unggah Ulang',
    'qrisTitle': 'Bayar dengan QRIS',
    'qrisAmount': 'Nominal yang dibayar',
    'qrisSteps': '1. Pindai QRIS ini dengan aplikasi bank atau e-wallet.\n2. Bayar sesuai nominal.\n3. Ambil tangkapan layar bukti bayar, lalu unggah di sini.',
    'qrisMissing':
        'Gambar QRIS tidak bisa dimuat. Periksa koneksimu dan coba lagi.',
    'qrisUpload': 'Unggah Bukti Bayar',
    'qrisSent': 'Bukti terkirim. Menunggu konfirmasi admin (maks. 1×24 jam).',
    'qrisFailed': 'Bukti tidak bisa dikirim. Periksa koneksimu dan coba lagi.',
    'paymentsAdminTitle': 'Pembayaran',
    'paymentsEmpty': 'Tidak ada pembayaran yang menunggu.',
    'paymentsLoadFailed': 'Daftar pembayaran tidak bisa dimuat.',
    'paymentDetailTitle': 'Pembayaran',
    'paymentProof': 'Bukti bayar',
    'paymentProofFailed': 'Bukti tidak bisa dimuat.',
    'paymentMember': 'Member',
    'paymentKind': 'Jenis',
    'paymentExpected': 'Nominal seharusnya',
    'paymentReceived': 'Nominal diterima (Rp)',
    'paymentReceivedInvalid': 'Isi nominal yang benar-benar diterima.',
    'paymentConfirm': 'Konfirmasi',
    'paymentRejectTitle': 'Tolak pembayaran dari {name}?',
    'paymentRejectReason': 'Alasan (dibaca member)',
    'paymentReasonRequired': 'Isi alasan, maksimal 500 karakter.',
    'paymentConfirmed': 'Pembayaran dari {name} dikonfirmasi.',
    'paymentRejected': 'Pembayaran dari {name} ditolak.',
    'paymentNotPending': 'Pembayaran ini sudah diputuskan admin lain.',
    'errorInvalidAmount': 'Nominal diterima harus lebih dari 0.',
    'errorPaymentPending': 'Pembayaran terakhirmu masih menunggu konfirmasi admin. Kamu bisa membeli lagi setelah dikonfirmasi atau ditolak.',
    'listingError_category': 'Pilih kategori.',
    'listingError_photos': 'Tambahkan 1–5 foto.',
    'listingError_title': 'Isi nama maksimal 100 karakter.',
    'listingError_description': 'Isi deskripsi maksimal 500 karakter.',
    'listingError_condition': 'Pilih kondisi.',
    'listingError_price': 'Isi harga Rp 1.000 sampai Rp 50.000.000.',
    'listingError_stock': 'Stok minimal 1.',
    'listingError_specs': 'Maksimal 10 baris.',
    'orderNeedsApproval_guest':
        'Masuk dengan akun terverifikasi untuk booking atau membeli.',
    'orderNeedsApproval_incomplete':
        'Selesaikan verifikasi akunmu untuk booking atau membeli.',
    'orderNeedsApproval_pending': 'Akunmu sedang diverifikasi. Kamu bisa booking atau membeli setelah disetujui.',
    'orderNeedsApproval_rejected':
        'Verifikasimu ditolak. Kirim ulang untuk booking atau membeli.',
    'bookingTitle': 'Booking Barang',
    'bookingIntro': 'Kamu akan melakukan booking untuk {title}.',
    'bookingHeld': 'Barang akan ditahan selama',
    'booking24': '24 Jam',
    'bookingAutoCancel': 'Setelah 24 jam, booking akan otomatis dibatalkan dan barang kembali tersedia untuk Binusian lain.',
    'bookingNoPayment': 'Tidak ada pembayaran saat booking.',
    'bookingConfirm': 'Booking Sekarang',
    'bookingStatusTitle': 'Status Booking',
    'bookingDone': 'Berhasil di-booking!',
    'bookingDoneBody': 'Barang telah ditahan selama 24 jam.',
    'holdLeftTitle': 'Sisa waktu booking',
    'hours': 'Jam',
    'minutes': 'Menit',
    'seconds': 'Detik',
    'holdWarning': 'Setelah waktu habis, booking akan otomatis dibatalkan.',
    'checkoutTitle': 'Checkout',
    'codLocation': 'Lokasi COD',
    'change': 'Ubah',
    'codPlace': 'Titik temu (opsional)',
    'codPlaceHint': 'mis. Lobi Anggrek, depan ATM',
    'save': 'Simpan',
    'paymentMethod': 'Metode Pembayaran',
    'codMethod': 'COD di kampus',
    'codMethodBody': 'Bayar tunai saat bertemu penjual di kampus.',
    'orderSummary': 'Ringkasan Pesanan',
    'orderQty': 'qty: {n}',
    'subtotal': 'Subtotal',
    'total': 'Total',
    'checkoutCodOnly':
        'Pembayaran hanya dilakukan langsung saat COD di kampus.',
    'checkoutConfirm': 'Konfirmasi Pesanan',
    'ordersTitle': 'Pesanan Saya',
    'ordersPurchases': 'Pembelian',
    'ordersSales': 'Penjualan',
    'orderFilter_all': 'Semua',
    'orderFilter_waiting': 'Menunggu',
    'orderFilter_processing': 'Diproses',
    'orderFilter_completed': 'Selesai',
    'orderFilter_cancelled': 'Dibatalkan',
    'orderStatus_waiting': 'Menunggu konfirmasi penjual',
    'orderStatus_processing': 'Diproses',
    'orderStatus_completed': 'Selesai',
    'orderStatus_cancelled': 'Dibatalkan',
    'holdLeft': 'Sisa {time}',
    'ordersEmpty': 'Belum ada pesanan di sini.',
    'ordersLoadFailed':
        'Pesanan tidak bisa dimuat. Periksa koneksimu dan coba lagi.',
    'orderDetailTitle': 'Detail Pesanan',
    'orderKind': 'Jenis',
    'orderKind_booking': 'Booking 24 Jam',
    'orderKind_buy': 'Beli Sekarang',
    'orderStatus': 'Status',
    'orderPrice': 'Harga',
    'orderSeller': 'Penjual',
    'orderBuyer': 'Pembeli',
    'codTime': 'Waktu COD',
    'codTimeUnset': 'Diisi penjual saat menerima pesanan.',
    'autoCompleteNote': 'Selesai otomatis 3 hari setelah waktu COD bila pembeli belum mengonfirmasi.',
    'extensionRequested': 'Pembeli meminta tambahan 24 jam.',
    'cancelledAuto': 'Dibatalkan otomatis: tidak diterima tepat waktu.',
    'cancelledReason': 'Alasan: {reason}',
    'orderAction_accept': 'Terima',
    'orderAction_reject': 'Tolak',
    'orderAction_cancel': 'Batalkan pesanan',
    'orderAction_complete': 'Sudah diterima',
    'orderAction_requestExtension': 'Minta perpanjangan 24 jam',
    'orderAction_approveExtension': 'Setujui perpanjangan 24 jam',
    'orderAction_updateLocation': 'Ubah Lokasi COD',
    'orderAction_updateCodTime': 'Ubah waktu COD',
    'cancelTitle': 'Batalkan pesanan ini?',
    'cancelReason_changed_mind': 'Berubah pikiran',
    'cancelReason_not_as_described': 'Barang tidak sesuai',
    'cancelReason_cannot_meet': 'Tidak bisa bertemu',
    'cancelReason_sold_elsewhere': 'Sudah terjual di luar',
    'cancelReason_other': 'Lainnya',
    'cancelNote': 'Catatan',
    'cancelReasonRequired':
        'Pilih alasan. Untuk Lainnya, tulis catatan (maksimal 500 karakter).',
    'cancelOrder': 'Ya, batalkan',
    'orderUpdated': 'Pesanan diperbarui.',
    'errorListingUnavailable': 'Barang ini sudah tidak tersedia.',
    'errorOwnListing': 'Kamu tidak bisa memesan barangmu sendiri.',
    'errorSoldOut': 'Unit terakhir baru saja diambil orang lain.',
    'errorAlreadyOrdered':
        'Kamu sudah punya pesanan berjalan untuk barang ini.',
    'errorDonationLimit': 'Kamu sudah punya 2 pesanan donasi berjalan. Selesaikan atau batalkan salah satunya dulu.',
    'errorOrderTransition':
        'Pesanan ini sudah berubah. Status terbarunya ditampilkan.',
    'errorNotParty': 'Kamu bukan pihak dalam pesanan ini.',
    'errorCodTimeMissing': 'Isi waktu COD.',
    'errorCodTimePast': 'Pilih waktu COD mulai sekarang.',
    'codPlaceTooLong': 'Maksimal 200 karakter.',
  },
};
