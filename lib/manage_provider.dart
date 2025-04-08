import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ManageProvidersPage extends StatefulWidget {
  @override
  _ManageProvidersPageState createState() => _ManageProvidersPageState();
}

class _ManageProvidersPageState extends State<ManageProvidersPage> {
  final DatabaseReference _userRef =
      FirebaseDatabase.instance.ref('userprofiles');
  final DatabaseReference _receiptRef =
      FirebaseDatabase.instance.ref('Gcash-receipts');
  final DatabaseReference _gcashNumberRef =
      FirebaseDatabase.instance.ref('gcash-number');
  List<Map<String, dynamic>> _providers = [];
  int _totalProviders = 0;

  @override
  void initState() {
    super.initState();
    _fetchProviders();
  }

  Future<void> _fetchProviders() async {
    final snapshot = await _userRef.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;

      setState(() {
        _providers = data.entries
            .map((entry) {
              final value = Map<String, dynamic>.from(entry.value);
              return {'key': entry.key, ...value};
            })
            .where((user) => user['userType'] == 'Provider') // Filter providers
            .toList();

        _totalProviders = _providers.length; // Update the total provider count
      });
    }
  }

  Future<void> _updateProviderStatus(String uid, bool isDisabled) async {
    try {
      await _userRef.child(uid).update({'disable': isDisabled});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDisabled
                ? 'Provider has been disabled successfully.'
                : 'Provider has been activated successfully.',
          ),
          backgroundColor: isDisabled ? Colors.red : Colors.green,
        ),
      );

      // Refresh the provider list
      _fetchProviders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating provider status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _viewReceipt(String uid) async {
    try {
      final snapshot = await _receiptRef.child(uid).get();

      if (snapshot.exists) {
        final receiptData = snapshot.value as Map<dynamic, dynamic>?;

        if (receiptData != null && receiptData['receiptUrl'] != null) {
          final receiptUrl = receiptData['receiptUrl'];
          final subscriptionPlan = receiptData['subscriptionPlan'] ?? 'Monthly';

          _showReceiptDialog(receiptUrl, uid, subscriptionPlan);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No receipt URL found for this provider.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No receipt data found for this provider.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showReceiptDialog(String imageUrl, String uid, String plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('GCash Receipt'),
          content: SizedBox(
            height: 300,
            width: 300,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _activateSubscription(uid, plan);
                Navigator.pop(context);
              },
              child: const Text('Activate Subscription'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _activateSubscription(String uid, String plan) async {
    try {
      final now = DateTime.now();
      DateTime endDate;

      if (plan == 'Yearly') {
        endDate = DateTime(now.year + 1, now.month, now.day);
      } else {
        endDate = DateTime(now.year, now.month + 1, now.day);
      }

      final subscriptionData = {
        'plan': plan,
        'start': now.toIso8601String(),
        'end': endDate.toIso8601String(),
      };

      final userRef = FirebaseDatabase.instance.ref('userprofiles/$uid');
      await userRef.update({'subscription': subscriptionData});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Subscription activated: $plan (Expires: ${endDate.toLocal()})'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to activate subscription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _viewFeedback(String uid) async {
    try {
      final snapshot = await _userRef.child('$uid/feedbacks').get();

      if (snapshot.exists) {
        final feedbackData = snapshot.value as Map<dynamic, dynamic>;

        final feedbackList = feedbackData.entries
            .map((entry) => Map<String, dynamic>.from(entry.value as Map))
            .toList();

        _showFeedbackDialog(feedbackList);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No feedback available for this provider.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching feedback: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFeedbackDialog(List<Map<String, dynamic>> feedbackList) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Provider Feedback'),
          content: SingleChildScrollView(
            child: Column(
              children: feedbackList.map((feedback) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(
                      feedback['fullName'] ?? 'Anonymous',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(feedback['feedback'] ?? 'No feedback'),
                        const SizedBox(height: 4),
                        Text(
                          'Rating: ${feedback['rating'] ?? "N/A"}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        Text(
                          'Timestamp: ${feedback['timestamp'] ?? ""}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddGcashDialog() async {
    TextEditingController _gcashNumberController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add GCash Number'),
          content: TextField(
            controller: _gcashNumberController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'GCash Number',
              hintText: 'Enter GCash Number',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_gcashNumberController.text.trim().isNotEmpty) {
                  await _gcashNumberRef.set({
                    'number': _gcashNumberController.text.trim(),
                    'timestamp': DateTime.now().toIso8601String(),
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('GCash number added successfully!')),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Please enter a valid GCash number.')),
                  );
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Providers'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddGcashDialog,
            tooltip: 'Add GCash Number',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Providers: $_totalProviders',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _providers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _providers.length,
                      itemBuilder: (context, index) {
                        final provider = _providers[index];
                        final subscription =
                            provider['subscription'] as Map<dynamic, dynamic>?;
                        final bool isDisabled = provider['disable'] ?? false;

                        bool isSubscriptionActive = false;

                        if (subscription != null &&
                            subscription['end'] != null) {
                          final endDate = DateTime.parse(subscription['end']);
                          isSubscriptionActive =
                              endDate.isAfter(DateTime.now());
                        }

                        final cardColor = isDisabled
                            ? Colors.grey[200]
                            : isSubscriptionActive
                                ? Colors.green[50]
                                : Colors.red[50];
                        final textColor = isDisabled
                            ? Colors.grey
                            : isSubscriptionActive
                                ? Colors.green[800]
                                : Colors.red[800];
                        final statusText = isDisabled
                            ? 'Disabled'
                            : isSubscriptionActive
                                ? 'Active'
                                : 'Expired';

                        return Card(
                          color: cardColor,
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${provider['firstName']} ${provider['lastName']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Email: ${provider['email']}\n'
                                            'Contact: ${provider['contactNumber'] ?? "N/A"}\n'
                                            'Subscription: $statusText',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (!isDisabled)
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _updateProviderStatus(
                                                    provider['key'], true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                            ),
                                            icon: const Icon(Icons.block),
                                            label: const Text('Disable'),
                                          ),
                                        if (isDisabled)
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _updateProviderStatus(
                                                    provider['key'], false),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                            ),
                                            icon: const Icon(Icons.check),
                                            label: const Text('Activate'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _viewReceipt(provider['key']),
                                        icon: const Icon(Icons.receipt_long,
                                            color: Colors.blue),
                                        label: const Text(
                                          'View Receipt',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: Colors.blue),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _viewFeedback(provider['key']),
                                        icon: const Icon(Icons.feedback,
                                            color: Colors.blue),
                                        label: const Text(
                                          'View Feedback',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: Colors.blue),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
