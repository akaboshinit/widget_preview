import 'dart:math';

import 'package:device_frame/device_frame.dart';
import 'package:flutter/material.dart';
import 'package:widget_preview/widget_preview.dart' show Preview, WidgetPreview;

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final sectionData = <_DashboardSectionData>[
      const _DashboardSectionData(
        title: 'Total Users',
        value: '1,200',
        icon: Icons.people,
        color: Colors.teal,
      ),
      const _DashboardSectionData(
        title: 'New Orders',
        value: '35',
        icon: Icons.shopping_cart,
        color: Colors.orange,
      ),
      const _DashboardSectionData(
        title: 'Revenue',
        value: '\$5,430',
        icon: Icons.attach_money,
        color: Colors.green,
      ),
      const _DashboardSectionData(
        title: 'Support Tickets',
        value: '12',
        icon: Icons.support_agent,
        color: Colors.red,
      ),
      const _DashboardSectionData(
        title: 'Total Users',
        value: '1,200',
        icon: Icons.people,
        color: Colors.teal,
      ),
      const _DashboardSectionData(
        title: 'New Orders',
        value: '35',
        icon: Icons.shopping_cart,
        color: Colors.orange,
      ),
      const _DashboardSectionData(
        title: 'Revenue',
        value: '\$5,430',
        icon: Icons.attach_money,
        color: Colors.green,
      ),
    ];

    return Column(
      children: [
        const CircularProgressIndicator.adaptive(),
        Text('Dashboard', style: Theme.of(context).textTheme.bodyLarge),
        SizedBox(
          height: 200,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6, // 2カラムにする
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1, // セクションカードの縦横比
            ),
            itemCount: sectionData.length,
            itemBuilder: (context, index) {
              final data = sectionData[index];
              return _DashboardSection(
                title: data.title,
                value: data.value,
                icon: data.icon,
                color: data.color,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ダッシュボードカードごとのデータモデル (内部的に使うだけなのでプライベート)
class _DashboardSectionData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardSectionData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

// ダッシュボードの個別セクションウィジェット (内部ウィジェット)
class _DashboardSection extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardSection({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Icon(
                icon,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class RotatingFadingBox extends StatefulWidget {
  const RotatingFadingBox({super.key});

  @override
  RotatingFadingBoxState createState() => RotatingFadingBoxState();
}

class RotatingFadingBoxState extends State<RotatingFadingBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.5 + _controller.value * 0.5; // スケール範囲: 0.5～1.0
        final opacity = 0.5 + _controller.value * 0.5; // 不透明度範囲: 0.5～1.0
        return Transform.rotate(
          angle: _controller.value * 2 * pi,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 100,
                height: 100,
                color: Colors.blue,
              ),
            ),
          ),
        );
      },
    );
  }
}

class TapEffectWidget extends StatefulWidget {
  const TapEffectWidget({super.key});

  @override
  _TapEffectWidgetState createState() => _TapEffectWidgetState();
}

class _TapEffectWidgetState extends State<TapEffectWidget> {
  final List<_RippleEffect> _ripples = [];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        setState(() {
          _ripples.add(_RippleEffect(localPosition));
        });

        // タイマーで一定時間後に Ripple を削除
        Future.delayed(const Duration(milliseconds: 600), () {
          setState(() {
            _ripples.removeAt(0);
          });
        });
      },
      child: Stack(
        children: [
          Container(
            color: Colors.grey[300],
          ),
          for (final ripple in _ripples)
            Positioned(
              left: ripple.offset.dx - ripple.radius / 2,
              top: ripple.offset.dy - ripple.radius / 2,
              child: RippleAnimation(
                radius: ripple.radius,
                onUpdate: (newRadius) {
                  setState(() {
                    ripple.radius = newRadius;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RippleEffect {
  Offset offset;
  double radius;

  _RippleEffect(this.offset) : radius = 0.0;
}

class RippleAnimation extends StatefulWidget {
  final double radius;
  final ValueChanged<double> onUpdate;

  const RippleAnimation({
    super.key,
    required this.radius,
    required this.onUpdate,
  });

  @override
  RippleAnimationState createState() => RippleAnimationState();
}

class RippleAnimationState extends State<RippleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.0, end: 100.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut))
      ..addListener(() {
        widget.onUpdate(_animation.value);
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.radius,
      height: widget.radius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.withValues(alpha: .3),
      ),
    );
  }
}

// @Preview()
// List<WidgetPreview> preview() => [
//       const WidgetPreview(child: Dashboard(), name: 'Dashboard'),
//       WidgetPreview(
//         child: const Dashboard(),
//         name: 'Dashboard on Android Phone',
//         device: DeviceInfo.genericPhone(
//           screenSize: const Size(360, 640),
//           pixelRatio: 2.0,
//           platform: TargetPlatform.android,
//           id: 'android',
//           name: 'Android Phone',
//         ),
//       ),
//       WidgetPreview(
//         child: const Dashboard(),
//         name: 'Dashboard on iOS Phone',
//         orientation: Orientation.landscape,
//         device: DeviceInfo.genericPhone(
//           screenSize: const Size(360, 640),
//           pixelRatio: 2.0,
//           platform: TargetPlatform.iOS,
//           id: 'ios',
//           name: 'iOS Phone',
//         ),
//       ),
//       const WidgetPreview(
//         child: Dashboard(),
//         name: 'Dashboard textScaleFactor: 3',
//         textScaleFactor: 3,
//       ),
//       WidgetPreview(
//         child: const Dashboard(),
//         name: 'Dashboard dark theme',
//         theme: ThemeData.light(),
//         darkTheme: ThemeData.dark().copyWith(
//           textTheme: ThemeData.dark().textTheme.copyWith(
//                 bodyMedium: const TextStyle(
//                   fontSize: 16,
//                   color: Colors.red,
//                 ),
//               ),
//         ),
//       ),
//       WidgetPreview(
//         child: const Dashboard(),
//         name: 'Dashboard android dark theme',
//         platformBrightness: Brightness.light,
//         theme: ThemeData.light().copyWith(
//           platform: TargetPlatform.android,
//         ),
//         darkTheme: ThemeData.dark().copyWith(
//           platform: TargetPlatform.android,
//           textTheme: ThemeData.dark().textTheme.copyWith(
//                 bodyLarge: const TextStyle(
//                   fontSize: 16,
//                   color: Colors.blue,
//                 ),
//                 bodyMedium: const TextStyle(
//                   fontSize: 16,
//                   color: Colors.red,
//                 ),
//               ),
//         ),
//       ),
//       const WidgetPreview(
//           child: RotatingFadingBox(), name: 'RotatingFadingBox'),
//       const WidgetPreview(
//         child: SizedBox(
//           height: 100,
//           child: TapEffectWidget(),
//         ),
//         name: 'TapEffectWidget',
//       ),
//     ];
