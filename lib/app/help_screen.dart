import 'package:firbird/app/app_drawer.dart';
import 'package:firbird/app/back_to_home_button.dart';
import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Kullanım Kılavuzu'),
        leading: Builder(
          builder: (BuildContext context) => IconButton(
            tooltip: 'Menü',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
          ),
        ),
        actions: const <Widget>[BackToHomeButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: <Widget>[
          _HelpSection(
            title: 'Kuş kartları',
            icon: Icons.view_agenda_outlined,
            children: <Widget>[
              const Text(
                'Kartın pastel arka planı güven puanını gösterir. Yeşil yüksek, turuncu orta, kırmızı düşük veya çelişkili güvendir.',
              ),
              const SizedBox(height: 10),
              _LegendRow(
                color: Colors.green,
                label: 'Yerel / göçmen çerçevesi',
              ),
              _LegendRow(
                color: Colors.grey,
                label: 'Bölge dışı / zor çerçevesi',
              ),
              _LegendRow(
                color: Colors.blue,
                label: 'Yeni / aktif tespit rozeti',
              ),
              const SizedBox(height: 8),
              const Text(
                'Nadir tür kartında “Nadir Tür” yazısı bulunur. Nadirlik güven puanından bağımsızdır.',
              ),
            ],
          ),
          _HelpSection(
            title: 'Nadir tür uyarısı',
            icon: Icons.notification_important_outlined,
            children: const <Widget>[
              Text(
                'Karar verilmemiş nadir tür kartı 15 saniyede bir turuncu parıltıyla uyarır. Karta dokunup Doğru veya Doğru değil seçildiğinde uyarı durur.',
              ),
              SizedBox(height: 8),
              Text(
                'Kart kaydırma nedeniyle görünmese bile tespit oturum raporunda sayılmaya devam eder. Aynı nadir türün tekrarları sayıyı artırmaz.',
              ),
            ],
          ),
          _HelpSection(
            title: 'Kanıt Dosyası',
            icon: Icons.fact_check_outlined,
            children: const <Widget>[
              Text(
                'Kuş kartına dokunduğunuzda güven puanını etkileyen saat, mevsim, yakın eBird kayıtları ve cihaz doğrulamaları gösterilir.',
              ),
              SizedBox(height: 8),
              Text(
                'Doğru veya Doğru değil kararınız cihaz doğrulama hafızasına eklenir ve sonraki kanıt puanlamalarında kullanılabilir.',
              ),
            ],
          ),
          _HelpSection(
            title: 'Tekrarlanan tespitler',
            icon: Icons.multitrack_audio_outlined,
            children: const <Widget>[
              Text(
                'Aynı tür ayrı ses olaylarında yeniden duyulursa model skorlarının ortalaması güncellenir. Örtüşen üç saniyelik analiz pencereleri yeni bir olay sayılmaz.',
              ),
              SizedBox(height: 8),
              Text(
                'Kartta model ortalaması ve kaç kez bağımsız duyulduğu ayrı gösterilir. Her ek tespitin destek puanı Ayarlar bölümünden değiştirilebilir.',
              ),
            ],
          ),
          _HelpSection(
            title: 'Ses filtresi (Ekolayzer)',
            icon: Icons.graphic_eq,
            children: const <Widget>[
              Text(
                'Canlı dinleme sırasında arka plandaki rüzgar ve su/dere gürültüleri kuş tanımlama modeline ulaşmadan önce gerçek zamanlı olarak temizlenebilir.',
              ),
              SizedBox(height: 8),
              Text(
                'Ayarlar bölümünden filtreyi açabilir; 🌬️ Rüzgar, 💧 Dere/Su veya 🌿 Orman profillerini seçebilir ya da rüzgar kesim frekansı (HPF), su azaltma ve ses güçlendirme slider’larını kendiniz ayarlayabilirsiniz.',
              ),
              SizedBox(height: 8),
              Text(
                'Baykuş veya kızılgerdan gibi düşük frekansta öten türleri dinlerken rüzgar filtresini daha düşük Hz seviyesinde tutmanız önerilir.',
              ),
            ],
          ),
          _HelpSection(
            title: 'Kuş Kartından Klip Dinleme & Paylaşma',
            icon: Icons.play_circle_outline,
            children: const <Widget>[
              Text(
                'Oynatıcı ekranındaki her kuş kartında bulunan ▶ butonuna dokunduğunuzda, tespit anının 10 saniye öncesi ile 10 saniye sonrası arasındaki 20 saniyelik bölüm otomatik olarak dinletilir.',
              ),
              SizedBox(height: 8),
              Text(
                'Klip bittiğinde oynatma kendiliğinden durur ve beliren Klip Barı üzerinden ses bölümü 💾 Kaydet düğmesiyle cihazınıza kaydedilebilir veya 📤 Paylaş düğmesiyle WhatsApp, AirDrop vb. üzerinden paylaşılabilir.',
              ),
            ],
          ),
          _HelpSection(
            title: 'Kılavuza erişim',
            icon: Icons.help_outline,
            children: const <Widget>[
              Text(
                'Kullanım kılavuzu uygulamaya gömülüdür ve internet bağlantısı gerektirmez. Sol menüden veya ekranların sağ üstündeki soru işaretinden açabilirsiniz.',
              ),
            ],
          ),
          Text(
            'FirBird v0.8.9',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    ),
  );
}
