/// Marketing Landing Page
///
/// PURPOSE:
/// Public-facing marketing page for D'Sierra Painting
/// Showcases services and drives lead generation
///
/// FEATURES:
/// - Hero section with CTA button
/// - Services grid with icons
/// - Testimonials carousel
/// - Contact form
/// - Responsive design (mobile + desktop)
/// - D'Sierra branding throughout
///
/// HAIKU TODO:
/// - Build hero section with background image
/// - Create services grid widget
/// - Add testimonials carousel
/// - Implement contact form with Cloud Function
/// - Add smooth scroll to sections
/// - Optimize for SEO
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:sierra_painting/design/tokens.dart';

/// Testimonial model for carousel
class Testimonial {
  final String quote;
  final String clientName;
  final String company;
  final double rating;

  Testimonial({
    required this.quote,
    required this.clientName,
    required this.company,
    required this.rating,
  });
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late ScrollController _scrollController;
  late GlobalKey<FormState> _formKey;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _messageController;
  bool _isSubmitting = false;

  // Mock testimonials data
  final List<Testimonial> _testimonials = [
    Testimonial(
      quote: 'D\'Sierra Painting transformed our home. The attention to detail and professionalism was outstanding!',
      clientName: 'Sarah Johnson',
      company: 'Homeowner',
      rating: 5.0,
    ),
    Testimonial(
      quote: 'We\'ve hired them multiple times for commercial projects. Always on time, always perfect quality.',
      clientName: 'Michael Chen',
      company: 'Property Manager',
      rating: 5.0,
    ),
    Testimonial(
      quote: 'The team was respectful of our space and cleaned up thoroughly. Highly recommend!',
      clientName: 'Jennifer Davis',
      company: 'Business Owner',
      rating: 5.0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _formKey = GlobalKey<FormState>();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Smooth scroll to contact section
  void _scrollToContact() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  /// Submit contact form via Cloud Function
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('createLead')
          .call({
            'name': _nameController.text,
            'email': _emailController.text,
            'phone': _phoneController.text,
            'message': _messageController.text,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! We\'ll contact you soon with a quote.'),
            backgroundColor: Colors.green,
          ),
        );
        // Clear form
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // Hero section
            _buildHeroSection(context),

            // Services section
            _buildServicesSection(context),

            // Testimonials section
            _buildTestimonialsSection(context),

            // Contact section
            _buildContactSection(context),

            // Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      height: 600,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DesignTokens.dsierraRed,
            DesignTokens.dsierraRed.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // HAIKU TODO: Add D'Sierra logo
              Image.asset(
                'assets/branding/dsierra_logo.jpg',
                height: 120,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
              const SizedBox(height: DesignTokens.spaceXL),

              Text(
                "D' Sierra Painting",
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.spaceMD),

              Text(
                'Professional Painting Services You Can Trust',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.spaceXL),

              // CTA button with smooth scroll to contact
              FilledButton.icon(
                onPressed: _scrollToContact,
                icon: const Icon(Icons.contact_mail),
                label: const Text('Get Free Quote'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: DesignTokens.dsierraRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceXL,
                    vertical: DesignTokens.spaceLG,
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceXXL),
      child: Column(
        children: [
          Text(
            'Our Services',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: DesignTokens.dsierraRed,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: DesignTokens.spaceXL),

          // HAIKU TODO: Services grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 3 : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: DesignTokens.spaceLG,
                crossAxisSpacing: DesignTokens.spaceLG,
                childAspectRatio: 1.2,
                children: [
                  _buildServiceCard(
                    context,
                    'Interior Painting',
                    Icons.home,
                    'Transform your indoor spaces with precision',
                  ),
                  _buildServiceCard(
                    context,
                    'Exterior Painting',
                    Icons.house,
                    'Weather-resistant finishes for lasting beauty',
                  ),
                  _buildServiceCard(
                    context,
                    'Commercial Projects',
                    Icons.business,
                    'Professional solutions for businesses',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    String title,
    IconData icon,
    String description,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: DesignTokens.dsierraRed),
            const SizedBox(height: DesignTokens.spaceMD),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spaceSM),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestimonialsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceXXL),
      color: Colors.grey[100],
      child: Column(
        children: [
          Text(
            'What Our Clients Say',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: DesignTokens.dsierraRed,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: DesignTokens.spaceXL),

          // Testimonials carousel with PageView
          SizedBox(
            height: 300,
            child: PageView.builder(
              itemCount: _testimonials.length,
              itemBuilder: (context, index) {
                return _buildTestimonialCard(_testimonials[index]);
              },
            ),
          ),

          // Indicator dots
          const SizedBox(height: DesignTokens.spaceLG),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _testimonials.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DesignTokens.dsierraRed.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialCard(Testimonial testimonial) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMD),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),

            // Quote
            Text(
              '"${testimonial.quote}"',
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spaceLG),

            // Client name
            Text(
              '— ${testimonial.clientName}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),

            // Company
            Text(
              testimonial.company,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceXXL),
      child: Column(
        children: [
          Text(
            'Get Your Free Quote',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: DesignTokens.dsierraRed,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: DesignTokens.spaceXL),

          // Contact form with Cloud Function integration
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: DesignTokens.spaceMD),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: DesignTokens.spaceMD),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: DesignTokens.spaceMD),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Tell us about your project',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please describe your project';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: DesignTokens.spaceLG),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitForm,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isSubmitting ? 'Submitting...' : 'Request Quote'),
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignTokens.dsierraRed,
                      padding: const EdgeInsets.all(DesignTokens.spaceMD),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceXL),
      color: DesignTokens.dsierraRed,
      child: const Column(
        children: [
          Text(
            "© 2025 D' Sierra Painting LLC. All rights reserved.",
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: DesignTokens.spaceSM),
          Text(
            'Professional. Reliable. Beautiful.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
