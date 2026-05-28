import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _version = '0.1.0';
const _releaseDate = 'May 28, 2026';
const _repoUrl = 'https://github.com/rzuasti/oott';
const _licenseUrl = 'https://www.gnu.org/licenses/agpl-3.0.html';
const _licenseName = 'GNU Affero General Public License v3 (AGPL-3.0)';

class About extends StatelessWidget {
  const About({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About OOTT', style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            'Easy to setup and use network device discovery and alert system. '
            'Notifies you when new or unknown devices join your local area network.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'v$_version - released $_releaseDate',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _SurfaceContainer(
            colorScheme: colorScheme,
            child: Column(
              children: [
                _LinkRow(
                  icon: Icons.code,
                  label: 'Source code',
                  url: _repoUrl,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant,
                  indent: 16,
                  endIndent: 16,
                ),
                _LicenseRow(colorScheme: colorScheme, textTheme: textTheme),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SurfaceContainer(
            colorScheme: colorScheme,
            padding: const EdgeInsets.all(16),
            child: _NoticesSection(textTheme: textTheme),
          ),
        ],
      ),
    );
  }
}

class _SurfaceContainer extends StatelessWidget {
  const _SurfaceContainer({
    required this.colorScheme,
    required this.child,
    this.padding,
  });

  final ColorScheme colorScheme;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.url,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String label;
  final String url;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  Future<void> _open() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LicenseRow extends StatelessWidget {
  const _LicenseRow({required this.colorScheme, required this.textTheme});

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  Future<void> _open() async {
    final uri = Uri.parse(_licenseUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.gavel, size: 18, color: colorScheme.primary),
          const SizedBox(width: 12),
          Flexible(
            child: Wrap(
              children: [
                Text('Licensed under ', style: textTheme.bodyMedium),
                InkWell(
                  onTap: _open,
                  child: Text(
                    _licenseName,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticesSection extends StatelessWidget {
  const _NoticesSection({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OOTT, Copyright (C) 2024-2026 Ricardo Zuasti',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'This product includes software developed by third parties and distributed '
          'under the Apache License, Version 2.0.',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ..._thirdPartyComponents.map(
          (c) => _ThirdPartyEntry(component: c, textTheme: textTheme),
        ),
      ],
    );
  }
}

class _ThirdPartyEntry extends StatelessWidget {
  const _ThirdPartyEntry({required this.component, required this.textTheme});

  final _ThirdPartyComponent component;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            component.name,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            component.copyright,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SelectableText(
            component.url,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _ThirdPartyComponent {
  const _ThirdPartyComponent({
    required this.name,
    required this.copyright,
    required this.url,
  });

  final String name;
  final String copyright;
  final String url;
}

const _thirdPartyComponents = [
  _ThirdPartyComponent(
    name: 'openssl',
    copyright:
        'Copyright 2011-2017 Google Inc., 2013 Jack Lloyd, 2013-2014 Steven Fackler. Apache-2.0.',
    url: 'https://github.com/rust-openssl/rust-openssl',
  ),
  _ThirdPartyComponent(
    name: 'rusqlite_migration',
    copyright: 'Copyright Clément Joly and contributors. Apache-2.0.',
    url: 'https://github.com/cljoly/rusqlite_migration',
  ),
  _ThirdPartyComponent(
    name: 'sync_wrapper',
    copyright: 'Copyright Actyx AG. Apache-2.0.',
    url: 'https://github.com/Actyx/sync_wrapper',
  ),
  _ThirdPartyComponent(
    name: 'zopfli',
    copyright:
        'Copyright the zopfli-rs contributors. Based on the original Zopfli C code by Google. Apache-2.0.',
    url: 'https://github.com/zopfli-rs/zopfli',
  ),
];
