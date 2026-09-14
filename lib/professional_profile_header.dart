
import 'package:flutter/material.dart';

/// Modern, professional profile header for Ricette del Mondo.
/// The avatar is optional; tapping it can be wired to the app's image picker.
class ProfessionalProfileHeader extends StatelessWidget {
  const ProfessionalProfileHeader({
    super.key,
    this.photoProvider,
    this.onPhotoTap,
    this.name = 'Il mio profilo',
    this.subtitle = 'Il tuo spazio personale',
  });

  final ImageProvider<Object>? photoProvider;
  final VoidCallback? onPhotoTap;
  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPhotoTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 39,
                  backgroundColor: theme.colorScheme.surface,
                  child: CircleAvatar(
                    radius: 35,
                    backgroundImage: photoProvider,
                    child: photoProvider == null
                        ? Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                ),
                if (onPhotoTap != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Material(
                      color: theme.colorScheme.secondary,
                      shape: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: .86),
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
