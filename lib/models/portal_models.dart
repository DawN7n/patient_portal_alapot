import 'package:flutter/material.dart';

class Dentist {
  const Dentist(
      {required this.id,
      required this.name,
      required this.specialty,
      required this.experience,
      required this.rating,
      required this.reviews,
      required this.bio,
      required this.color});
  final String id, name, specialty, experience, bio;
  final double rating;
  final int reviews;
  final Color color;
}

class DentalService {
  const DentalService(
      {required this.id,
      required this.name,
      required this.description,
      required this.price,
      required this.duration,
      required this.icon,
      required this.tint});
  final String id, name, description;
  final double price;
  final int duration;
  final IconData icon;
  final Color tint;
}
