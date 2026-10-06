/// All UI text, in two maps (D-11). English is the default.
enum Lang { en, id }

// ponytail: global language; the EN|ID toggle ticket makes it persisted and listenable.
Lang currentLang = Lang.en;

String t(String key) => copy[currentLang]![key]!;

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
    'errorPhoneRequired': 'Enter your phone number.',
    'errorInvalidPhone': 'Enter a valid phone number.',
    'errorPhoneTaken': 'This phone number is already registered.',
    'errorSignupUnknown': 'Registration failed. Please try again.',
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
    'errorPhoneRequired': 'Isi nomor HP.',
    'errorInvalidPhone': 'Masukkan nomor HP yang valid.',
    'errorPhoneTaken': 'Nomor HP ini sudah terdaftar.',
    'errorSignupUnknown': 'Pendaftaran gagal. Coba lagi.',
  },
};
