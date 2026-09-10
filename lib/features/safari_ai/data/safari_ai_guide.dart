class SafariDestination {
  const SafariDestination({
    required this.id,
    required this.name,
    required this.region,
    required this.hook,
    required this.why,
    required this.season,
    required this.fromKes,
    required this.vibe,
    required this.itinerary,
  });

  final String id;
  final String name;
  final String region;
  final String hook;
  final String why;
  final String season;
  final String fromKes;
  final String vibe;
  final List<String> itinerary;
}

class SafariAiChoice {
  const SafariAiChoice({required this.label, required this.nextId});

  final String label;
  final String nextId;
}

class SafariAiReply {
  const SafariAiReply({
    required this.nodeId,
    required this.text,
    this.picks = const [],
    this.choices = const [],
  });

  final String nodeId;
  final String text;
  final List<SafariDestination> picks;
  final List<SafariAiChoice> choices;

  List<String> get suggestions =>
      choices.map((choice) => choice.label).toList(growable: false);
}

class _SafariAiNode {
  const _SafariAiNode({
    required this.text,
    this.destinationIds = const [],
    this.choices = const [],
    this.showItinerary = false,
  });

  final String text;
  final List<String> destinationIds;
  final List<SafariAiChoice> choices;
  final bool showItinerary;
}

/// Scripted field-guide conversation. Every chip has a written answer.
class SafariAiSession {
  SafariAiSession() : _nodeId = 'start';

  String _nodeId;

  SafariAiReply get opening => _render('start');

  SafariAiReply advance(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return _render(_nodeId);

    final current = _nodes[_nodeId];
    if (current != null) {
      for (final choice in current.choices) {
        if (_same(choice.label, input)) {
          _nodeId = choice.nextId;
          return _render(_nodeId);
        }
      }
    }

    final jumped = _jumpFromFreeText(input);
    if (jumped != null) {
      _nodeId = jumped;
      return _render(_nodeId);
    }

    return SafariAiReply(
      nodeId: _nodeId,
      text:
          'I only walk the marked trails on this mock. Tap one of the choices below — that is how we pick the next camp.',
      choices: current?.choices ?? _nodes['start']!.choices,
    );
  }

  void reset() {
    _nodeId = 'start';
  }

  SafariAiReply _render(String id) {
    final node = _nodes[id] ?? _nodes['start']!;
    _nodeId = _nodes.containsKey(id) ? id : 'start';
    final picks = [
      for (final destId in node.destinationIds)
        if (_byId.containsKey(destId)) _byId[destId]!,
    ];
    return SafariAiReply(
      nodeId: _nodeId,
      text: node.showItinerary && picks.isNotEmpty
          ? '${node.text}\n\n${picks.first.itinerary.map((line) => '• $line').join('\n')}'
          : node.text,
      picks: picks,
      choices: node.choices,
    );
  }

  static bool _same(String a, String b) =>
      a.toLowerCase().trim() == b.toLowerCase().trim();

  static String? _jumpFromFreeText(String raw) {
    final q = raw.toLowerCase();
    if (_greeting(q)) return 'start';
    if (q.contains('start over') || q.contains('begin again')) return 'start';
    if (q.contains('gorilla') || q.contains('rwanda')) return 'gorilla_confirm';
    if (q.contains('weekend') || q.contains('nairobi') || q.contains('friday')) {
      return 'weekend_who';
    }
    if (q.contains('20k') || q.contains('budget') || q.contains('cheap')) {
      return 'budget_nights';
    }
    if (q.contains('big five') || q.contains('big 5') || q.contains('mara')) {
      return 'bigfive_style';
    }
    if (q.contains('beach') || q.contains('coast') || q.contains('ocean')) {
      return 'beach_style';
    }
    if (q.contains('culture') || q.contains('lamu') || q.contains('slow')) {
      return 'culture_where';
    }
    if (q.contains('remote') || q.contains('quiet') || q.contains('samburu')) {
      return 'dest_samburu';
    }
    return null;
  }

  static bool _greeting(String q) {
    const greetings = ['hi', 'hey', 'hello', 'habari', 'sasa', 'yo'];
    return greetings.contains(q);
  }

  static final _byId = {for (final dest in destinations) dest.id: dest};

  static const destinations = <SafariDestination>[
    SafariDestination(
      id: 'mara',
      name: 'Maasai Mara',
      region: 'Kenya · Greater Mara',
      hook: 'Dawn light, lion country, and the river crossings you came for.',
      why:
          'Classic safari — cats on the move, balloon rides, and camps that still feel like camp.',
      season: 'Jul–Oct for the migration; Jan–Mar for cubs and clear skies',
      fromKes: 'From KES 42,000 / person (2 nights, mid-range)',
      vibe: 'Big five · Iconic',
      itinerary: [
        'Day 1 — Wilson hop to the conservancy. Sundowner on a ridge.',
        'Day 2 — Full-day game drive. Picnic by the Talek if the herds allow.',
        'Day 3 — Optional balloon, then fly back before Nairobi traffic wakes up.',
      ],
    ),
    SafariDestination(
      id: 'diani',
      name: 'Diani Beach',
      region: 'Kenya · South Coast',
      hook: 'White sand, a forest behind you, and nowhere you need to be.',
      why:
          'Salt on your skin after a dusty week. Snorkel in the morning, Swahili supper at night.',
      season: 'Dec–Mar and Jul–Oct; avoid the long rains if you can',
      fromKes: 'From KES 18,500 / person (3 nights)',
      vibe: 'Beach · Reset',
      itinerary: [
        'Day 1 — SGR or flight to Ukunda. Barefoot dinner on the tide line.',
        'Day 2 — Kisite-Mpunguti dhow. Dolphins if the channel is kind.',
        'Day 3 — Slow morning, then the forest boardwalk at Colobus.',
      ],
    ),
    SafariDestination(
      id: 'amboseli',
      name: 'Amboseli',
      region: 'Kenya · Kajiado',
      hook: 'Elephants in dust, Kilimanjaro pretending it is not there.',
      why:
          'Close enough for a real weekend, big enough to feel like you left.',
      season: 'Jun–Oct and Jan–Feb for the clearest Kili views',
      fromKes: 'From KES 16,000 / person (1–2 nights)',
      vibe: 'Weekend · Elephants',
      itinerary: [
        'Day 1 — Leave Nairobi at 06:30. Observation Hill at golden hour.',
        'Day 2 — Dawn drive for the mountain, then the dusty road home.',
      ],
    ),
    SafariDestination(
      id: 'lamu',
      name: 'Lamu Old Town',
      region: 'Kenya · Lamu Archipelago',
      hook: 'No cars. Donkeys, dhows, and a town that still keeps time by the tide.',
      why: 'Walk, write, eat mandazi, let Shela beach empty your head.',
      season: 'Jul–Mar; Lamu Cultural Festival if you like a crowd with taste',
      fromKes: 'From KES 22,000 / person (3 nights)',
      vibe: 'Culture · Slow',
      itinerary: [
        'Day 1 — Fly into Manda. Boat to Shela. Sunset from the dunes.',
        'Day 2 — Old Town on foot. Fresh juice, carved doors, no agenda.',
        'Day 3 — Morning sail, then the short hop home.',
      ],
    ),
    SafariDestination(
      id: 'naivasha',
      name: 'Lake Naivasha',
      region: 'Kenya · Rift Valley',
      hook: 'Hippos at the jetty and a fire pit you can reach after work on Friday.',
      why:
          'The honest Nairobi weekend. Boat the lake, walk Crescent Island, spend what you would on a loud Saturday in town.',
      season: 'Year-round; cooler and clearer Jun–Aug',
      fromKes: 'From KES 8,500 / person (1 night)',
      vibe: 'Weekend · Budget',
      itinerary: [
        'Friday — Beat the rush, check in, boat before dark.',
        'Saturday — Crescent Island walk, Hell’s Gate bike if the kids still have legs.',
      ],
    ),
    SafariDestination(
      id: 'samburu',
      name: 'Samburu',
      region: 'Kenya · Northern Frontier',
      hook: 'Dry country, unique game, and almost nobody in the next vehicle.',
      why:
          'Reticulated giraffe, gerenuk, and silence that has a temperature.',
      season: 'Jun–Oct; dramatic storms Nov–Dec if you like sky',
      fromKes: 'From KES 28,000 / person (2 nights)',
      vibe: 'Remote · Wild',
      itinerary: [
        'Day 1 — Scheduled flight north. River camp, then a late drive.',
        'Day 2 — Full day in the reserve. Look up — the sky does half the work.',
        'Day 3 — One last dawn, then south again.',
      ],
    ),
    SafariDestination(
      id: 'gorillas',
      name: 'Volcanoes National Park',
      region: 'Rwanda · Musanze',
      hook: 'An hour on a mountain with a gorilla family. Nothing else compares.',
      why:
          'Permits are the whole plot. Book early, walk slowly, let lakes and Kigali be the epilogue.',
      season: 'Jun–Sep and Dec–Feb are driest underfoot',
      fromKes: 'From KES 185,000 / person (permit + 2 nights)',
      vibe: 'Once-in-a-lifetime',
      itinerary: [
        'Day 1 — Kigali to Musanze. Briefing and an early night.',
        'Day 2 — Trek. You will talk about the hour in the clearing for years.',
        'Day 3 — Coffee or Lake Kivu if your legs forgive you.',
      ],
    ),
    SafariDestination(
      id: 'zanzibar',
      name: 'Zanzibar',
      region: 'Tanzania · Spice Islands',
      hook: 'Stone Town at dusk, then a sea so blue it looks edited.',
      why: 'Bush-and-beach in one stamp. Spice tour if you must, Nungwi if you came to float.',
      season: 'Jun–Oct and Dec–Mar; the kusi wind has opinions',
      fromKes: 'From KES 35,000 / person (3 nights)',
      vibe: 'Beach + culture',
      itinerary: [
        'Day 1 — Stone Town. Forodhani at night. Do not rush the alleyways.',
        'Day 2 — Coast. Jozani if you want red colobus in the canopy.',
        'Day 3 — Nothing. That is the point.',
      ],
    ),
    SafariDestination(
      id: 'tsavo',
      name: 'Tsavo East',
      region: 'Kenya · Taita–Taveta',
      hook: 'Red dust on everything, including the elephants.',
      why:
          'Space. Proper, unfashionable space — game without the Mara convoy.',
      season: 'Jun–Oct; green season has its own drama',
      fromKes: 'From KES 14,000 / person (2 nights)',
      vibe: 'Vast · Value',
      itinerary: [
        'Day 1 — Mombasa road or the park airstrip. Mudanda Rock at last light.',
        'Day 2 — Aruba and the Galana. Count the red elephants, lose count.',
      ],
    ),
  ];

  static const _nodes = <String, _SafariAiNode>{
    'start': _SafariAiNode(
      text:
          'I am Safari AI — your field guide for the next place that will actually stick.\n\n'
          'Pick a mood. Each choice has a destination already written behind it.',
      choices: [
        SafariAiChoice(label: 'Weekend out of Nairobi', nextId: 'weekend_who'),
        SafariAiChoice(label: 'Beach, I am done with dust', nextId: 'beach_style'),
        SafariAiChoice(label: 'Classic big five', nextId: 'bigfive_style'),
        SafariAiChoice(label: 'Keep it under 20k', nextId: 'budget_nights'),
        SafariAiChoice(
          label: 'Something slow and cultural',
          nextId: 'culture_where',
        ),
        SafariAiChoice(label: 'Gorillas. Just gorillas.', nextId: 'gorilla_confirm'),
      ],
    ),
    'weekend_who': _SafariAiNode(
      text:
          'A Nairobi Friday can still end somewhere with hippos or elephants. Who is in the car?',
      choices: [
        SafariAiChoice(label: 'Just us two', nextId: 'dest_amboseli'),
        SafariAiChoice(label: 'Family with kids', nextId: 'dest_naivasha'),
        SafariAiChoice(label: 'Solo, I need air', nextId: 'dest_naivasha'),
      ],
    ),
    'beach_style': _SafariAiNode(
      text:
          'Good. Dust off. How should the water feel — a Kenyan reset, or a boat ride into another century?',
      choices: [
        SafariAiChoice(label: 'Stay in Kenya, keep it easy', nextId: 'dest_diani'),
        SafariAiChoice(label: 'Donkeys, dhows, no cars', nextId: 'dest_lamu'),
        SafariAiChoice(label: 'Stone Town and that blue', nextId: 'dest_zanzibar'),
      ],
    ),
    'bigfive_style': _SafariAiNode(
      text:
          'Cats it is. Do you want the postcard, the empty track, or more land for less money?',
      choices: [
        SafariAiChoice(label: 'The postcard — Maasai Mara', nextId: 'dest_mara'),
        SafariAiChoice(label: 'Fewer vehicles', nextId: 'dest_samburu'),
        SafariAiChoice(label: 'More space, better value', nextId: 'dest_tsavo'),
      ],
    ),
    'budget_nights': _SafariAiNode(
      text:
          'Under twenty thousand is honest if we stay close or go lean. How many nights?',
      choices: [
        SafariAiChoice(label: 'One night, Friday exit', nextId: 'dest_naivasha'),
        SafariAiChoice(label: 'Two nights, still lean', nextId: 'dest_tsavo'),
        SafariAiChoice(label: 'I can stretch for elephants', nextId: 'dest_amboseli'),
      ],
    ),
    'culture_where': _SafariAiNode(
      text:
          'Slow is a real itinerary. Kenya’s archipelago, or Tanzania’s spice island?',
      choices: [
        SafariAiChoice(label: 'Lamu — alleys and tide', nextId: 'dest_lamu'),
        SafariAiChoice(label: 'Zanzibar — stone and sea', nextId: 'dest_zanzibar'),
      ],
    ),
    'gorilla_confirm': _SafariAiNode(
      text:
          'Rwanda does not do half measures. The permit is the trip. Still in?',
      choices: [
        SafariAiChoice(label: 'Yes. Book the mountain.', nextId: 'dest_gorillas'),
        SafariAiChoice(label: 'Too steep — surprise me', nextId: 'dest_samburu'),
      ],
    ),
    'fork_again': _SafariAiNode(
      text: 'Different trail. Same rules — tap what you want next.',
      choices: [
        SafariAiChoice(label: 'Weekend out of Nairobi', nextId: 'weekend_who'),
        SafariAiChoice(label: 'Beach, I am done with dust', nextId: 'beach_style'),
        SafariAiChoice(label: 'Classic big five', nextId: 'bigfive_style'),
        SafariAiChoice(label: 'Keep it under 20k', nextId: 'budget_nights'),
        SafariAiChoice(
          label: 'Something slow and cultural',
          nextId: 'culture_where',
        ),
        SafariAiChoice(label: 'Gorillas. Just gorillas.', nextId: 'gorilla_confirm'),
      ],
    ),
    'dest_mara': _SafariAiNode(
      text:
          'Maasai Mara. Dawn light, lion country, the river crossings you came for. Mid-range sits around KES 42,000 a person for two nights.',
      destinationIds: ['mara'],
      choices: [
        SafariAiChoice(label: 'Sketch this trip', nextId: 'plan_mara'),
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Add a beach after', nextId: 'dest_diani'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'dest_diani': _SafariAiNode(
      text:
          'Diani. White sand, a forest behind you, nowhere you need to be. From about KES 18,500 for three nights.',
      destinationIds: ['diani'],
      choices: [
        SafariAiChoice(label: 'Sketch this trip', nextId: 'plan_diani'),
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Make it more cultural', nextId: 'dest_lamu'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'dest_amboseli': _SafariAiNode(
      text:
          'Amboseli. Elephants in the dust and Kilimanjaro if the clouds behave. A real weekend from about KES 16,000.',
      destinationIds: ['amboseli'],
      choices: [
        SafariAiChoice(label: 'Sketch this trip', nextId: 'plan_amboseli'),
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Cheaper and closer', nextId: 'dest_naivasha'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'dest_lamu': _SafariAiNode(
      text:
          'Lamu. No cars. Donkeys, dhows, and a town that keeps time by the tide. From about KES 22,000 for three nights.',
      destinationIds: ['lamu'],
      choices: [
        SafariAiChoice(label: 'Sketch this trip', nextId: 'plan_lamu'),
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'I want more beach club', nextId: 'dest_diani'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'dest_naivasha': _SafariAiNode(
      text:
          'Lake Naivasha. Hippos at the jetty, Crescent Island in the morning, home before Sunday traffic thickens. From about KES 8,500.',
      destinationIds: ['naivasha'],
      choices: [
        SafariAiChoice(label: 'Sketch this trip', nextId: 'plan_naivasha'),
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Upgrade the weekend', nextId: 'dest_amboseli'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'dest_samburu': _SafariAiNode(
      text:
          'Samburu. Dry country, unique game, almost nobody in the next vehicle. From about KES 28,000 for two nights.',
      destinationIds: ['samburu'],
      choices: [
        SafariAiChoice(label: 'Sketch this trip', nextId: 'plan_samburu'),
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'I want the classic Mara', nextId: 'dest_mara'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'dest_gorillas': _SafariAiNode(
      text:
          'Volcanoes National Park. An hour with a gorilla family. The permit is the plot — budget from about KES 185,000 with two nights.',
      destinationIds: ['gorillas'],
      choices: [
        SafariAiChoice(label: 'Sketch this trip', nextId: 'plan_gorillas'),
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'dest_zanzibar': _SafariAiNode(
      text:
          'Zanzibar. Stone Town at dusk, then a sea that looks edited. From about KES 35,000 for three nights.',
      destinationIds: ['zanzibar'],
      choices: [
        SafariAiChoice(label: 'Sketch this trip', nextId: 'plan_zanzibar'),
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Keep it in Kenya', nextId: 'dest_diani'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'dest_tsavo': _SafariAiNode(
      text:
          'Tsavo East. Red dust on everything, including the elephants. Two lean nights from about KES 14,000.',
      destinationIds: ['tsavo'],
      choices: [
        SafariAiChoice(label: 'Sketch this trip', nextId: 'plan_tsavo'),
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'I can spend more', nextId: 'dest_mara'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'plan_mara': _SafariAiNode(
      text: 'Three days, written like a ranger’s notes. Camps move with the season — this is a sketch, not a quote.',
      destinationIds: ['mara'],
      showItinerary: true,
      choices: [
        SafariAiChoice(label: 'Add a beach after', nextId: 'dest_diani'),
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'plan_diani': _SafariAiNode(
      text: 'A coast sketch. Leave room for a day that does nothing.',
      destinationIds: ['diani'],
      showItinerary: true,
      choices: [
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'plan_amboseli': _SafariAiNode(
      text: 'Two days. Early start or do not bother — the mountain is a morning animal.',
      destinationIds: ['amboseli'],
      showItinerary: true,
      choices: [
        SafariAiChoice(label: 'Cheaper and closer', nextId: 'dest_naivasha'),
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'plan_lamu': _SafariAiNode(
      text: 'Three days with almost no timetable. That is the luxury.',
      destinationIds: ['lamu'],
      showItinerary: true,
      choices: [
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'plan_naivasha': _SafariAiNode(
      text: 'Friday to Saturday. You will still make the office on Monday.',
      destinationIds: ['naivasha'],
      showItinerary: true,
      choices: [
        SafariAiChoice(label: 'Upgrade the weekend', nextId: 'dest_amboseli'),
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'plan_samburu': _SafariAiNode(
      text: 'Three days north. Bring a book for the heat in the middle of the day.',
      destinationIds: ['samburu'],
      showItinerary: true,
      choices: [
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'plan_gorillas': _SafariAiNode(
      text: 'The walk is the ceremony. Sleep early. The hour in the clearing is the whole story.',
      destinationIds: ['gorillas'],
      showItinerary: true,
      choices: [
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'plan_zanzibar': _SafariAiNode(
      text: 'Stone first, sea second. Do not reverse it unless you like leaving early.',
      destinationIds: ['zanzibar'],
      showItinerary: true,
      choices: [
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
    'plan_tsavo': _SafariAiNode(
      text: 'Two days of red earth. Self-drive works if you like your own dust.',
      destinationIds: ['tsavo'],
      showItinerary: true,
      choices: [
        SafariAiChoice(label: 'Show me a different place', nextId: 'fork_again'),
        SafariAiChoice(label: 'Start over', nextId: 'start'),
      ],
    ),
  };
}
