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
    'registerDataWarning':
        'Make sure your details are correct and match your BINUS identity.',
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
    'registerDataWarning':
        'Pastikan data sudah benar dan sesuai identitas BINUS.',
  },
};
