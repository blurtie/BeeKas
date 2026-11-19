# Draf Kebijakan Privasi: admin membaca chat yang dilaporkan (K-24)

Status: draf untuk T12, belum aktif. Fungsi backend `admin_report_messages` sudah ada (#87),
tetapi aplikasi belum memanggilnya. Layar cuplikan chat untuk admin baru dibangun setelah
teks ini masuk ke Kebijakan Privasi (`lib/config/copy.dart`, `consentVersion` naik) dan
disetujui.

## ID

**Pesan chat yang dilaporkan.** Pesan chat hanya bisa dibaca oleh kamu dan lawan chatmu.
Bila kamu atau lawan chatmu melaporkan percakapan itu, admin BeeKas bisa membaca pesan
dalam percakapan tersebut untuk meninjau laporan. Akses ini hanya ada selama laporan
masih terbuka dan berakhir saat admin menurunkan listing, mengabaikan laporan, atau
mengambil tindakan lain. Admin tidak bisa membaca percakapan yang tidak dilaporkan.

## EN

**Reported chats.** Only you and the other member can read your chat messages. If either
of you reports the conversation, a BeeKas admin can read its messages to review the
report. This access lasts only while the report is open and ends once an admin takes the
listing down, dismisses the report, or takes other action. Admins cannot read
conversations that have not been reported.
