import 'package:flutter/material.dart';
import 'package:hymns_latest/categories/category1.dart';
import 'package:hymns_latest/categories/category2.dart';
import 'package:hymns_latest/categories/category3.dart';
import 'package:hymns_latest/categories/category4.dart';
import 'package:hymns_latest/categories/category5.dart';

class SidebarOptions {
  static List<Widget> getOptions(BuildContext context) {
    return [
      ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Category1Screen()),
          );
        },
        leading: const SizedBox(
          height: 34,
          width: 34,
          child: Icon(Icons.collections_bookmark),
        ),
        title: Text(
          "Christmas",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Category2Screen()),
          );
        },
        leading: const SizedBox(
          height: 34,
          width: 34,
          child: Icon(Icons.collections_bookmark),
        ),
        title: Text(
          "Lent and Good Friday",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Category3Screen()),
          );
        },
        leading: const SizedBox(
          height: 34,
          width: 34,
          child: Icon(Icons.collections_bookmark),
        ),
        title: Text(
          "Easter",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Category4Screen()),
          );
        },
        leading: const SizedBox(
          height: 34,
          width: 34,
          child: Icon(Icons.collections_bookmark),
        ),
        title: Text(
          "Jesus' Ascension and His Kingdom",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Category5Screen()),
          );
        },
        leading: const SizedBox(
          height: 34,
          width: 34,
          child: Icon(Icons.collections_bookmark),
        ),
        title: Text(
          "Jesus' Coming Again",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    ];
  }
}
