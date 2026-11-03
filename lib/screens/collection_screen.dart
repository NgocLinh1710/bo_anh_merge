import 'package:flutter/material.dart';
import 'game_screen.dart';

import '../main.dart';
import '../models/game_collection.dart';
import '../services/collection_service.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late Future<List<GameCollection>> collectionsFuture;

  @override
  void initState() {
    super.initState();
    collectionsFuture = CollectionService.loadCollections();
  }

  void selectCollection(GameCollection collection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(collection: collection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chọn bộ ảnh',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.cream, AppColors.butterLight, Color(0xFFF0E9FC)],
          ),
        ),
        child: FutureBuilder<List<GameCollection>>(
          future: collectionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.butterDark),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Không thể tải bộ sưu tập.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.text),
                  ),
                ),
              );
            }

            final collections = snapshot.data ?? [];

            if (collections.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 64,
                        color: AppColors.butterDark,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Chưa có bộ sưu tập nào!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Hãy thêm ảnh JPG vào thư mục collection_1 '
                        'hoặc collection_2 rồi chạy lại ứng dụng.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.text, height: 1.5),
                      ),
                    ],
                  ),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 4
                    : constraints.maxWidth >= 600
                    ? 3
                    : 2;

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: collections.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    final collection = collections[index];

                    return _CollectionCard(
                      collection: collection,
                      onTap: () => selectCollection(collection),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final GameCollection collection;
  final VoidCallback onTap;

  const _CollectionCard({required this.collection, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    collection.imagePath(1),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: AppColors.butterLight,
                        child: const Icon(
                          Icons.image_rounded,
                          size: 52,
                          color: AppColors.butterDark,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                collection.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${collection.availableLevels.length} ảnh • '
                '${collection.maxLevel} cấp độ',
                style: const TextStyle(fontSize: 12, color: AppColors.text),
              ),
              const SizedBox(height: 10),
              const Text(
                'CHỌN  →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.butterDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
