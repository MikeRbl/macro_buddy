import 'package:flutter/material.dart';

import '../../core/widgets/build_footer.dart';
import '../../theme/app_theme.dart';

/// "Acerca de": de dónde salen los datos de alimentos y bajo qué licencia.
/// La atribución a Open Food Facts es obligatoria por la ODbL.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final body = TextStyle(color: c.textSecondary, fontSize: 14, height: 1.45);

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );

    // shortcut: las URLs son texto seleccionable, no enlaces; agrega
    // url_launcher si se quiere abrir el navegador.
    Widget link(String url) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SelectableText(
        url,
        style: const TextStyle(color: AppColors.secondaryCyan, fontSize: 14),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppColors.screenPadding),
          children: [
            section('Base de datos de alimentos', [
              Text(
                'El catálogo de MacroBuddy combina tres fuentes: productos '
                'empacados de Open Food Facts, alimentos genéricos y productos '
                'registrados y verificados por la comunidad de MacroBuddy.',
                style: body,
              ),
            ]),
            section('Open Food Facts', [
              Text(
                'Los datos de productos con código de barras provienen de '
                'Open Food Facts, una base de datos abierta y colaborativa de '
                'alimentos de todo el mundo.',
                style: body,
              ),
              link('https://openfoodfacts.org'),
              const SizedBox(height: 10),
              Text(
                'La base de datos se distribuye bajo la Open Database License '
                '(ODbL) y su contenido bajo la Database Contents License '
                '(DbCL). MacroBuddy filtra, corrige y agrupa esos datos; el '
                'catálogo resultante se ofrece bajo la misma licencia ODbL.',
                style: body,
              ),
              link('https://opendatacommons.org/licenses/odbl/1-0/'),
              link('https://opendatacommons.org/licenses/dbcl/1-0/'),
            ]),
            section('Exactitud de los datos', [
              Text(
                'Los valores nutricionales son informativos y pueden contener '
                'errores. Si un producto está mal, regístralo con los datos '
                'de la etiqueta y envíalo a verificación desde "Mis '
                'alimentos".',
                style: body,
              ),
            ]),
            const SizedBox(height: 8),
            const BuildFooter(),
          ],
        ),
      ),
    );
  }
}
