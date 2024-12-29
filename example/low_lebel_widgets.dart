import 'package:flutter/material.dart';
import 'package:widget_preview/widget_preview.dart' show Preview, WidgetPreview;

class Text1 extends StatelessWidget {
  const Text1({super.key});

  @override
  Widget build(BuildContext context) => const Text('Hello World!');
}

class UserProfile extends StatelessWidget {
  const UserProfile({
    super.key,
    required this.name,
    required this.bio,
    required this.avatarUrl,
  });

  final String name;
  final String bio;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: NetworkImage(avatarUrl),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              bio,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}

@Preview()
List<WidgetPreview> preview() => [
      const WidgetPreview(child: Text1(), name: 'Text1'),
      const WidgetPreview(
        name: 'UserProfile',
        child: UserProfile(
          name: 'John Doe',
          bio: 'Software Engineer',
          avatarUrl: 'https://avatars.githubusercontent.com/u/12345678',
        ),
      )
    ];
