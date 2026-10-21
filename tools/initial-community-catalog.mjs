const sources = Object.freeze({
  search: 'https://blog.google/products-and-platforms/products/search/year-in-search-2025/',
  spotify: 'https://newsroom.spotify.com/2025-12-03/wrapped-top-artists-songs-albums-podcasts-audiobooks/',
  technology: 'https://www.weforum.org/publications/top-10-emerging-technologies-of-2025/in-full/',
  communities: 'https://redditinc.com/policies/transparency-report-july-to-december-2025-reddit',
  travel: 'https://www.unwto.org/tourism-data/global-and-regional-tourism-performance',
  health: 'https://www.who.int/news-room/fact-sheets/detail/physical-activity',
  developers: 'https://github.blog/news-insights/octoverse/octoverse-2025/',
});

const rows = [
  // 20 broad global interests.
  ['global','AI Builders','ai-builders','Technology','Practical discussion for people building useful artificial intelligence products, workflows, and responsible experiments.','technology'],
  ['global','Personal Finance','personal-finance','General','A practical space for budgeting, saving, investing basics, and making informed everyday money decisions.','search'],
  ['global','Global Football','global-football','Sport','Independent discussion of clubs, national teams, tactics, players, and football culture around the world.','communities'],
  ['global','Healthy Living','healthy-living','Fitness & Wellness','Evidence-minded habits for movement, food, sleep, recovery, and sustainable everyday wellbeing.','health'],
  ['global','Gaming World','gaming-world','Gaming','Players share discoveries, strategies, recommendations, and thoughtful conversation across every kind of game.','communities'],
  ['global','Movies and Series','movies-and-series','Movies & TV','A welcoming place to discuss films, television, performances, storytelling, and what to watch next.','search'],
  ['global','Music Discovery','music-discovery','Music','Find new artists, exchange playlists, and discuss the sounds and scenes shaping music worldwide.','spotify'],
  ['global','Travel Planning','travel-planning','Travel','Practical itineraries, responsible travel ideas, local etiquette, and advice for better trips.','travel'],
  ['global','Home Cooking','home-cooking','Food & Cooking','Reliable recipes, cooking techniques, ingredient ideas, and encouragement for everyday home cooks.','search'],
  ['global','Climate Action','climate-action','General','Constructive discussion of climate science, adaptation, conservation, and realistic actions for communities.','technology'],
  ['global','Space Exploration','space-exploration','Technology','Missions, astronomy, spacecraft, and the science expanding humanity’s view of the universe.','technology'],
  ['global','Photography','photography','Art & Creativity','Improve composition, lighting, editing, and visual storytelling across cameras and phones.','communities'],
  ['global','Books and Reading','books-and-reading','Books & Reading','Readers exchange recommendations, thoughtful reviews, reading goals, and conversations across genres.','spotify'],
  ['global','Fitness Training','fitness-training','Fitness & Wellness','Inclusive training discussion covering strength, endurance, mobility, recovery, and sustainable progress.','health'],
  ['global','Career Growth','career-growth','Work','Practical guidance for skills, interviews, leadership, career changes, and healthier working lives.','search'],
  ['global','Language Learning','language-learning','Study','Learners share study methods, cultural context, practice resources, and motivation for steady progress.','search'],
  ['global','Parenting and Family','parenting-and-family','Social','Supportive, respectful conversation about family routines, learning, caregiving, and growing together.','communities'],
  ['global','Science and Discovery','science-and-discovery','Study','Accessible discussion of research, scientific methods, discoveries, and how evidence changes understanding.','technology'],
  ['global','Entrepreneurship','entrepreneurship','Work','Founders and builders discuss validation, operations, customers, resilient teams, and responsible growth.','search'],
  ['global','Technology News','technology-news','Technology','Context-rich conversation about important technology developments and their real-world consequences.','technology'],

  // 20 focused interests with durable communities.
  ['niche','Mechanical Keyboards','mechanical-keyboards','Hobbies & Interests','Switches, layouts, keycaps, acoustics, ergonomics, and careful advice for custom keyboard builders.','communities'],
  ['niche','Home Coffee Brewing','home-coffee-brewing','Food & Cooking','Methods, grinders, beans, water, and repeatable techniques for making better coffee at home.','communities'],
  ['niche','Urban Gardening','urban-gardening','Hobbies & Interests','Grow herbs, vegetables, and resilient plants in balconies, windows, rooftops, and small spaces.','communities'],
  ['niche','Birdwatching','birdwatching','Hobbies & Interests','Responsible observation, identification help, field notes, habitats, and appreciation of wild birds.','communities'],
  ['niche','3D Printing','3d-printing','Technology','Design, materials, calibration, troubleshooting, and useful projects for additive manufacturing enthusiasts.','technology'],
  ['niche','Board Game Strategy','board-game-strategy','Gaming','Thoughtful strategy, recommendations, teaching tips, and table-friendly discussion for modern board games.','communities'],
  ['niche','Trail Running','trail-running','Fitness & Wellness','Training, safety, routes, equipment, and respect for nature for runners who prefer the trails.','health'],
  ['niche','Astrophotography','astrophotography','Art & Creativity','Capture the night sky through better planning, tracking, optics, exposure, and patient image processing.','technology'],
  ['niche','Fermentation Lab','fermentation-lab','Food & Cooking','Safe techniques, recipes, troubleshooting, and experimentation with fermented foods and drinks.','communities'],
  ['niche','Indie Game Development','indie-game-development','Gaming','Small teams and solo creators discuss design, production, testing, publishing, and sustainable scope.','developers'],
  ['niche','Digital Nomad Life','digital-nomad-life','Travel','Responsible remote-work travel, logistics, routines, community etiquette, and realistic long-stay planning.','travel'],
  ['niche','Sustainable Fashion','sustainable-fashion','Hobbies & Interests','Repair, reuse, materials, labor, personal style, and lower-impact approaches to clothing.','search'],
  ['niche','Fountain Pens and Journaling','fountain-pens-journaling','Hobbies & Interests','Pens, inks, paper, handwriting, planning, and reflective journaling without productivity pressure.','communities'],
  ['niche','Aquascaping','aquascaping','Art & Creativity','Aquatic layouts, plant health, water balance, livestock care, and patient aquarium design.','communities'],
  ['niche','Drone Photography','drone-photography','Art & Creativity','Safe, lawful flight planning plus composition, capture, and editing for aerial photographers.','technology'],
  ['niche','Retro Computing','retro-computing','Technology','Preservation, repair, software, hardware history, and creative projects with classic computers.','communities'],
  ['niche','Home Automation','home-automation','Technology','Reliable, privacy-aware smart home projects, standards, sensors, routines, and troubleshooting.','technology'],
  ['niche','Miniature Painting','miniature-painting','Art & Creativity','Brush control, color, basing, airbrushing, and constructive feedback for painted miniatures.','communities'],
  ['niche','Open Source Makers','open-source-makers','Technology','Collaborative software and hardware projects, maintainership, documentation, and welcoming contributions.','developers'],
  ['niche','Accessible Design','accessible-design','Art & Creativity','Inclusive product, service, and communication design grounded in practical accessibility principles.','technology'],

  // 60 additional popular and emerging interests.
  ['additional','Cybersecurity Practice','cybersecurity-practice','Technology','Defensive security, privacy, threat awareness, and ethical learning for safer digital systems.','technology'],
  ['additional','Data Science','data-science','Technology','Data analysis, visualization, statistics, reproducible work, and responsible interpretation of results.','developers'],
  ['additional','Robotics','robotics','Technology','Robots, sensors, control systems, embedded projects, and hands-on engineering problem solving.','technology'],
  ['additional','Electric Vehicles','electric-vehicles','Technology','Independent discussion of electric cars, charging, batteries, ownership, and transport transitions.','technology'],
  ['additional','Smartphones and Mobile Tech','smartphones-mobile-tech','Technology','Independent advice and discussion about mobile devices, apps, privacy, repair, and useful features.','search'],
  ['additional','PC Building','pc-building','Technology','Compatible parts, balanced builds, cooling, troubleshooting, upgrades, and practical performance advice.','communities'],
  ['additional','Linux Users','linux-users','Technology','Friendly help with Linux desktops, servers, distributions, commands, and open computing.','developers'],
  ['additional','UX and Product Design','ux-product-design','Art & Creativity','Research, interaction design, product thinking, testing, and clear experiences for real users.','developers'],
  ['additional','Web Development','web-development','Technology','Modern frontend and backend development, standards, performance, accessibility, and maintainable code.','developers'],
  ['additional','Cloud Engineering','cloud-engineering','Technology','Architecture, reliability, cost awareness, automation, observability, and secure cloud operations.','developers'],
  ['additional','Sandbox Game Builders','sandbox-game-builders','Gaming','Independent player community for ambitious builds, survival ideas, redstone-style systems, and collaboration.','communities'],
  ['additional','Creature Collecting Games','creature-collecting-games','Gaming','Independent fan discussion of teams, collecting, strategy, exploration, and creature-focused games.','communities'],
  ['additional','Cozy Games','cozy-games','Gaming','Relaxing games, welcoming recommendations, creative play, and low-pressure experiences across platforms.','communities'],
  ['additional','Esports','esports','Gaming','Independent discussion of competitive gaming, teams, events, strategy, and player development.','communities'],
  ['additional','Sim Racing','sim-racing','Gaming','Driving technique, hardware, setups, racecraft, leagues, and realistic motorsport simulation.','communities'],
  ['additional','Chess Improvement','chess-improvement','Gaming','Puzzles, openings, calculation, game review, and steady improvement for chess players.','communities'],
  ['additional','Tabletop Roleplaying','tabletop-roleplaying','Gaming','Campaign ideas, inclusive tables, worldbuilding, rules discussion, and better collaborative storytelling.','communities'],
  ['additional','Anime and Manga','anime-and-manga','Movies & TV','Independent recommendations and respectful discussion of animation, comics, creators, and storytelling.','communities'],
  ['additional','K-Pop Fans','k-pop-fans','Music','Independent fan conversation about releases, performances, choreography, artists, and Korean pop culture.','spotify'],
  ['additional','Hip-Hop Culture','hip-hop-culture','Music','Music, production, history, dance, art, and thoughtful conversation across global hip-hop scenes.','spotify'],
  ['additional','English Football Fans','english-football-fans','Sport','Independent discussion of English leagues, clubs, players, matches, and supporter culture.','communities'],
  ['additional','Basketball Fans','basketball-fans','Sport','Independent conversation about basketball leagues, teams, tactics, players, and grassroots play.','communities'],
  ['additional','Formula Racing Fans','formula-racing-fans','Sport','Independent discussion of single-seater racing, drivers, engineering, strategy, and race weekends.','communities'],
  ['additional','Cricket Fans','cricket-fans','Sport','Independent match discussion, formats, tactics, players, and cricket culture around the world.','communities'],
  ['additional','Tennis Players and Fans','tennis-players-fans','Sport','Technique, equipment, tournaments, players, and encouragement for recreational tennis.','communities'],
  ['additional','Cycling','cycling','Sport','Road, gravel, commuting, maintenance, training, safety, and welcoming cycling culture.','health'],
  ['additional','Combat Sports','combat-sports','Sport','Respectful discussion of training, technique, events, athlete safety, and combat-sport disciplines.','health'],
  ['additional','Everyday Running','everyday-running','Fitness & Wellness','Sustainable training, injury awareness, motivation, races, and support for runners at every pace.','health'],
  ['additional','Yoga Practice','yoga-practice','Fitness & Wellness','Accessible yoga, mobility, breathing, consistency, and respectful learning across experience levels.','health'],
  ['additional','Strength Training','strength-training','Fitness & Wellness','Programming, technique, recovery, equipment, and evidence-minded strength development.','health'],
  ['additional','Budget Travel','budget-travel','Travel','Plan rewarding trips with realistic budgets, smart logistics, local respect, and fewer costly surprises.','travel'],
  ['additional','Solo Travel','solo-travel','Travel','Safety, confidence, planning, connection, and responsible advice for people travelling independently.','travel'],
  ['additional','Japan Travel Planning','japan-travel-planning','Travel','Independent planning help for transport, neighborhoods, etiquette, seasons, food, and varied Japan itineraries.','travel'],
  ['additional','Hiking','hiking','Travel','Routes, preparation, navigation, safety, equipment, and low-impact enjoyment of the outdoors.','health'],
  ['additional','Camping','camping','Travel','Campsite skills, equipment, meals, safety, and responsible outdoor trips from simple to ambitious.','communities'],
  ['additional','Aviation Enthusiasts','aviation-enthusiasts','Hobbies & Interests','Independent conversation about aircraft, airports, flight operations, engineering, and aviation history.','communities'],
  ['additional','Plant Based Cooking','plant-based-cooking','Food & Cooking','Flavorful vegetable-forward recipes, nutrition-aware ideas, techniques, and practical substitutions.','search'],
  ['additional','Bread and Baking','bread-and-baking','Food & Cooking','Dough, pastry, fermentation, ovens, troubleshooting, and dependable baking practice.','search'],
  ['additional','World Street Food','world-street-food','Food & Cooking','Explore street-food traditions, techniques, stories, and respectful home adaptations from many cultures.','travel'],
  ['additional','Mental Wellbeing','mental-wellbeing','Fitness & Wellness','Supportive habits, credible resources, reflection, and peer encouragement without replacing professional care.','health'],
  ['additional','Better Sleep','better-sleep','Fitness & Wellness','Evidence-minded routines, environments, and habits for more consistent and restorative sleep.','health'],
  ['additional','Meditation Practice','meditation-practice','Fitness & Wellness','Practical meditation methods, consistency, reflection, and welcoming discussion for beginners and regulars.','health'],
  ['additional','Skincare Science','skincare-science','Fitness & Wellness','Evidence-aware skincare routines, ingredients, sun protection, and realistic expectations.','search'],
  ['additional','Home Workouts','home-workouts','Fitness & Wellness','Adaptable strength, cardio, and mobility sessions using limited space and equipment.','health'],
  ['additional','Romantasy Readers','romantasy-readers','Books & Reading','Romance-forward fantasy recommendations, character discussion, reading lists, and spoiler-aware conversation.','spotify'],
  ['additional','Science Fiction and Fantasy','science-fiction-fantasy','Books & Reading','Books, worlds, ideas, characters, and recommendations across speculative fiction.','spotify'],
  ['additional','Mystery and Thriller Readers','mystery-thriller-readers','Books & Reading','Spoiler-aware recommendations and discussion of mysteries, crime stories, suspense, and thrillers.','communities'],
  ['additional','Comics and Graphic Novels','comics-graphic-novels','Books & Reading','Independent discussion of sequential art, creators, series, storytelling, and accessible starting points.','communities'],
  ['additional','Creative Writing','creative-writing','Art & Creativity','Prompts, craft, revision, worldbuilding, feedback, and encouragement for writers across genres.','search'],
  ['additional','Independent Filmmaking','independent-filmmaking','Movies & TV','Writing, directing, cinematography, sound, editing, production, and achievable filmmaking workflows.','search'],
  ['additional','Music Production','music-production','Music','Recording, arrangement, synthesis, mixing, creative workflow, and constructive production feedback.','spotify'],
  ['additional','Renewable Energy','renewable-energy','Technology','Solar, wind, storage, grids, policy, and practical transitions toward cleaner energy systems.','technology'],
  ['additional','Biotechnology','biotechnology','Technology','Research, therapeutics, tools, ethics, and accessible discussion of advances in biotechnology.','technology'],
  ['additional','Quantum Technologies','quantum-technologies','Technology','Quantum computing, sensing, communication, research milestones, and realistic technical learning.','technology'],
  ['additional','Ocean Conservation','ocean-conservation','General','Marine ecosystems, restoration, pollution reduction, sustainable choices, and evidence-led conservation.','technology'],
  ['additional','Weather and Climate Science','weather-climate-science','Study','Forecasting, atmospheric science, climate evidence, extreme events, and careful interpretation of data.','technology'],
  ['additional','Archaeology and History','archaeology-history','Study','Evidence, discoveries, methods, places, and respectful discussion of human history and material culture.','search'],
  ['additional','Wildlife Conservation','wildlife-conservation','General','Habitats, species recovery, ethical observation, conservation science, and community-led protection.','technology'],
  ['additional','Remote Work','remote-work','Work','Communication, focus, collaboration, boundaries, tools, and healthier distributed work practices.','search'],
  ['additional','Productivity Systems','productivity-systems','Work','Practical planning, focus, knowledge management, and sustainable systems without hustle culture.','search'],
];

export const initialCommunityCatalog = Object.freeze(rows.map(([
  segment, name, slug, type, description, source,
]) => Object.freeze({
  segment,
  name,
  slug,
  type,
  language: 'English',
  description,
  accessMode: 'open',
  topic: slug,
  popularityEvidence: `Documented as a durable or current interest using ${source}.`,
  sourceUrls: [sources[source]],
})));

const allowedTypes = new Set([
  'General','Gaming','Sport','Music','Study','Travel','Show','Work','Social',
  'Events','Hobbies & Interests','Technology','Art & Creativity','Movies & TV',
  'Books & Reading','Food & Cooking','Fitness & Wellness','Other',
]);

export function validateInitialCommunityCatalog(catalog) {
  const errors = [];
  const names = new Set();
  const slugs = new Set();
  const segmentCounts = {global: 0, niche: 0, additional: 0};
  if (!Array.isArray(catalog)) return {communities: [], errors: ['catalog must be an array'], segmentCounts};
  for (const [index, item] of catalog.entries()) {
    const label = `record ${index + 1}`;
    if (!item || typeof item !== 'object') { errors.push(`${label}: invalid record`); continue; }
    if (!(item.segment in segmentCounts)) errors.push(`${label}: invalid segment`);
    else segmentCounts[item.segment] += 1;
    if (typeof item.name !== 'string' || item.name.trim().length < 3 || item.name.length > 30) errors.push(`${label}: invalid name`);
    if (names.has(item.name.toLowerCase())) errors.push(`${label}: duplicate name`);
    names.add(item.name.toLowerCase());
    if (typeof item.slug !== 'string' || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(item.slug) || item.slug.length > 60) errors.push(`${label}: invalid slug`);
    if (slugs.has(item.slug)) errors.push(`${label}: duplicate slug`);
    slugs.add(item.slug);
    if (!allowedTypes.has(item.type)) errors.push(`${label}: invalid type`);
    if (item.language !== 'English') errors.push(`${label}: invalid language`);
    if (!['open','approval'].includes(item.accessMode)) errors.push(`${label}: invalid access mode`);
    if (typeof item.description !== 'string' || item.description.trim().length < 30 || item.description.length > 280) errors.push(`${label}: invalid description`);
    if (typeof item.topic !== 'string' || item.topic.length === 0) errors.push(`${label}: invalid topic`);
    if (typeof item.popularityEvidence !== 'string' || item.popularityEvidence.length < 20) errors.push(`${label}: missing evidence`);
    if (!Array.isArray(item.sourceUrls) || item.sourceUrls.length === 0 || item.sourceUrls.some((url) => typeof url !== 'string' || !url.startsWith('https://'))) errors.push(`${label}: invalid sources`);
  }
  if (catalog.length !== 100) errors.push(`expected 100 records, found ${catalog.length}`);
  for (const [segment, expected] of Object.entries({global: 20, niche: 20, additional: 60})) {
    if (segmentCounts[segment] !== expected) errors.push(`expected ${expected} ${segment} records, found ${segmentCounts[segment]}`);
  }
  return {communities: catalog, errors, segmentCounts};
}
