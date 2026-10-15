import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// İnternet bağlantısı olmadığında gösterilen banner
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService().connectionStatusStream,
      initialData: ConnectivityService().isConnected,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true;
        
        return ClipRect(
          clipBehavior: Clip.hardEdge,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            height: isConnected ? 0 : 40,
            child: OverflowBox(
              minHeight: 0,
              maxHeight: 40,
              alignment: Alignment.topCenter,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isConnected ? 0 : 1,
                child: Container(
                  height: 40,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade800,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Çevrimdışı - Önbellek gösteriliyor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
    },
  );
  }
}






