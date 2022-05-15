import 'dart:async';
import 'dart:math' show min, max;

import 'package:github/github.dart';
import 'package:intl/intl.dart';

import 'lib/args.dart';
import 'lib/content_repos.dart';

Future<void> main(List<String> args) async {
  final parser = repoParser
    ..addFlag('csv-output',
        defaultsTo: false,
        abbr: 'v',
        negatable: true,
        help:
            'Outputs data in the following format: date,rank,repo,issues,stars.\n'
            'Useful for appending to a CSV file for graphing trends.\n'
            'Default is to export normally.');

  final argResults = parser.parse(args);
  if (argResults['help'] == true) {
    print('Prints a ranked list of the GitHub repos with the highest number of '
        'issues, based on the specified options.\n\n'
        'Usage: dart repo-issues.dart [options]\n\n'
        'Common options:');
    print(parser.usage);
    return;
  }

  final gitHub = GitHub();
  final query = 'stars:>10000';

  // GitHub pagination returns 30 results per page by default, per their API.
  var reposStream = gitHub.search.repositories(query, sort: 'stars', pages: 4);

  // filter archived and content-only repos
  if (argResults['include-archived-repos'] == false) {
    reposStream = reposStream.where((repo) => !repo.archived);
  }

  if (argResults['include-content-repos'] == false) {
    reposStream =
        reposStream.where((repo) => !contentRepos.contains(repo.fullName));
  }

  var repos = await reposStream.toList();

  // sort repos by issue count
  repos.sort((a, b) => b.openIssuesCount.compareTo(a.openIssuesCount));

  var maxResults = int.tryParse(argResults['results'] as String);
  maxResults ??= 100;

  repos = repos.sublist(0, min(maxResults, repos.length - 1));

  if (argResults['csv-output'] == false) {
    // find the longest repo name; we'll use this for padding the text later
    final maxRepoNameLength =
        repos.fold(0, (int t, Repository e) => max<int>(t, e.fullName.length));

    if (argResults['include-header'] == true) {
      print('  #  '
          '${"Repository".padRight(maxRepoNameLength)} '
          '${"Stars".padLeft(6)}'
          '${"Issues".padLeft(8)}');
    }

    for (var i = 0; i < min(repos.length, maxResults); i++) {
      final repo = repos[i];
      print('${(i + 1).toString().padLeft(3)}  '
          '${repo.fullName.padRight(maxRepoNameLength)} '
          '${repo.stargazersCount.toString().padLeft(6)}'
          '${repo.openIssuesCount.toString().padLeft(8)}');
    }
  } else {
    final date = DateFormat('yyyy/MM/dd HH:mm:ss').format(DateTime.now());

    for (var i = 0; i < min(repos.length, maxResults); i++) {
      final repo = repos[i];
      print(
          '$date,${i + 1},${repo.fullName},${repo.openIssuesCount},${repo.stargazersCount}');
    }
  }

  gitHub.dispose();
}
