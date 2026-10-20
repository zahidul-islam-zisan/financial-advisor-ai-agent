import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/route/app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_snackbar.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  late String email;
  String? videoUrl;

  @override
  void initState() {
    super.initState();
    email = FirebaseAuth.instance.currentUser?.email ?? 'User';
    tutorialVideo();
  }

  Future<void> tutorialVideo() async {
    try {
      final doc = await FirebaseFirestore.instance.collection("tutorial").doc("video").get();
      if (doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            videoUrl = doc.data()!["video_link"] as String?;
          });
        }
      }
    } catch (e) {
      log('Error fetching tutorial video: $e');
    }
  }

  Future<void> _launchUrl(dynamic url) async {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 9, 28, 60),
          title: const Text('Logout', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                FirebaseAuth.instance.signOut();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back, color: Colors.black),
        //   onPressed: () => Navigator.pop(context),
        // ),
        title: const Text(
          'Menu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _showLogoutDialog(context),
              child: const Text(
                "Logout",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildEmailItem(),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.auto_awesome,
            iconColor: AppColors.primary,
            title: 'AI Financial Assistant',
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.aiAssistant);
            },
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.facebook,
            iconColor: Colors.blue,
            title: 'Join Community',
            onTap: () {
              _launchUrl(
                Uri.parse("https://facebook.com/groups/1445491534190146/"),
              );
            },
          ),
          // const SizedBox(height: 12),
          // _buildMenuItem(
          //   icon: Icons.language,
          //   iconColor: Colors.orange,
          //   title: 'Language ( language )',
          //   onTap: () {},
          // ),
          const SizedBox(height: 12),
          // _buildMenuItem(
          //   icon: Icons.devices,
          //   iconColor: Colors.deepPurple,
          //   title: 'Device',
          //   onTap: () {},
          // ),
          // const SizedBox(height: 12),
          // _buildMenuItem(
          //   icon: Icons.ads_click,
          //   iconColor: Colors.green,
          //   title: 'My Ads',
          //   onTap: () {},
          // ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.play_circle_fill,
            iconColor: Colors.red,
            title: 'Watch the tutorial',
            onTap: () {
              if (videoUrl != null && videoUrl!.trim().isNotEmpty) {
                final uri = Uri.tryParse(videoUrl!);
                if (uri != null) {
                  _launchUrl(uri);
                } else {
                  CustomSnackbar.showError(
                    context: context,
                    message: "Invalid tutorial video URL.",
                  );
                }
              } else {
                CustomSnackbar.showError(
                  context: context,
                  message: "Tutorial video is currently unavailable.",
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.chat,
            iconColor: Colors.greenAccent[700]!,
            title: 'WhatsApp',
            onTap: () {
              _launchUrl(
                Uri.parse("https://chat.whatsapp.com/HSn1AgetW74L1Kn1aRyysl"),
              );
            },
          ),
          // const SizedBox(height: 12),
          // _buildMenuItem(
          //   icon: Icons.settings,
          //   iconColor: Colors.grey[700]!,
          //   title: 'More Settings',
          //   onTap: () {},
          // ),
          // const SizedBox(height: 12),
          // _buildMenuItem(
          //   isCircleImage: true,
          //   title: 'Developer and Team',
          //   onTap: () {},
          // ),
          // const SizedBox(height: 12),
          // _buildMenuItem(
          //   icon: Icons.share,
          //   iconColor: Colors.blueAccent,
          //   title: 'Share App',
          //   onTap: () {},
          // ),
          // _buildMenuItem(
          //   icon: Icons.description,
          //   title: 'Terms and Conditions',
          //   onTap: () {},
          // ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            onTap: () {
              _launchUrl(
                Uri.parse(
                  "https://docs.google.com/document/d/1iz4LthmZb1nX5tXRXhN2AkihNKMd4nAcQV0gQi1Gx9s/edit?usp=sharing",
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // const SizedBox(height: 12),
          // _buildMenuItem(
          //   icon: Icons.logout,
          //   iconColor: Colors.white,
          //   backgroundColor: Colors.red,
          //   title: 'Logout',
          //   onTap: () => _showLogoutDialog(context),
          // ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.delete_forever,
            iconColor: Colors.red,
            backgroundColor: Colors.red.withAlpha(20),
            title: 'Delete Account',
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    backgroundColor: const Color.fromARGB(255, 9, 28, 60),
                    title: const Text('Delete Account'),
                    content: const Text(
                      'Deleting your Pulse Expense account will permanently remove all your data. This action cannot be undone. Do you want to continue?',
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () {
                          launchUrl(
                            Uri.parse("https://forms.gle/Ew4Jw6iTsX8MHcEJ9"),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmailItem() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle, color: Colors.teal),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.copy_outlined,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: email));
              CustomSnackbar.showSuccess(
                context: context,
                message: 'Email copied to clipboard',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    IconData? icon,
    Color? iconColor,
    required String title,
    required VoidCallback onTap,
    bool isCircleImage = false,
    Color? backgroundColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (isCircleImage)
              const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black12,
                backgroundImage: NetworkImage(
                  'https://via.placeholder.com/150',
                ), // Placeholder for person image
              )
            else
              Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 24),
          ],
        ),
      ),
    );
  }
}
