import 'package:flutter/material.dart';
import 'package:test_bill/core/constants/colors.dart';
import 'package:test_bill/service/api_service.dart';

class ServerIpDialog extends StatefulWidget {
  const ServerIpDialog({super.key});

  @override
  State<ServerIpDialog> createState() => _ServerIpDialogState();
}

class _ServerIpDialogState extends State<ServerIpDialog> {
  final ApiService _api = ApiService.instance;
  late final TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: _api.getServerIp());
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _save(String ip) {
    _api.saveServerIp(ip);
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Server URL set to: ${_api.baseUrl}'),
        backgroundColor: AppColors.kBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCloud = _api.baseUrl == ApiService.productionUrl;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.cloud_sync_rounded, color: AppColors.kBlue),
          SizedBox(width: 10),
          Text(
            'Backend Server Address',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Switch to Hosted Cloud URL
          InkWell(
            onTap: () => _save(ApiService.productionUrl),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCloud ? AppColors.kBlue.withOpacity(0.12) : AppColors.kBgGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCloud ? AppColors.kBlue : Colors.grey.shade300,
                  width: isCloud ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done_rounded, color: AppColors.kBlue, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hosted Cloud Server',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.kTextDark),
                        ),
                        Text(
                          'https://billing-backend-hd2t.onrender.com/api',
                          style: TextStyle(fontSize: 10, color: AppColors.kSubtext),
                        ),
                      ],
                    ),
                  ),
                  if (isCloud) const Icon(Icons.check_circle_rounded, color: AppColors.kBlue, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'Or connect to Local PC Wi-Fi Server (e.g. 192.168.1.15:3000):',
            style: TextStyle(fontSize: 12, color: AppColors.kSubtext, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _ipController,
            decoration: InputDecoration(
              hintText: '192.168.1.15:3000 or localhost:3000',
              prefixIcon: const Icon(Icons.dns_rounded, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Active API Endpoint:\n${_api.baseUrl}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.kTextDark),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _save(''),
          child: const Text('Reset Cloud Default'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.kBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _save(_ipController.text.trim()),
          child: const Text('Save Local IP'),
        ),
      ],
    );
  }
}
