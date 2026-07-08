import 'package:flutter/material.dart';

class MenuFormularioPage extends StatefulWidget {
  const MenuFormularioPage({super.key});

  @override
  State<MenuFormularioPage> createState() => _MenuFormularioPageState();
}

class _MenuFormularioPageState extends State<MenuFormularioPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios Dinâmicos'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildFormButton(
            context: context,
            icon: Icons.house,
            title: 'Cadastro Família Atingida',
            subtitle: 'Registrar família e necessidades',
            onTap: () {
              Navigator.pushNamed(context, '/cadastro_familia');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFormButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF616595)),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF616595),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFb0b2ca),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: const Color(0xFF3A3F7A),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF3A3F7A),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
