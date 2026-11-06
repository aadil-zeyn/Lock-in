LOCK-IN — Product Requirements Document (PRD)

Product: Lock-in
Platform: Android (first release)
Framework: Flutter / Dart
Document version: 1.0
Status: Initial product specification
Product category: Fitness, strength training and workout tracking

---

1. Product vision

Lock-in is a premium personal fitness and strength-training application designed to make tracking workouts effortless while helping users understand their long-term physical progress.

The product combines two ideas:

1. The polished, minimal, visually appealing experience of Xiaomi Mi Fitness.
2. The depth, precision and functionality of dedicated strength-training applications.

Lock-in should not feel like a spreadsheet disguised as an app. It should feel like a premium fitness companion.

The application should help users:

- Plan and execute workouts.
- Track exercises, sets, repetitions and weights.
- Monitor progressive overload.
- Understand their strength progression.
- Track body weight and physical measurements.
- Review training history.
- Build consistency through useful feedback and visualizations.

Core philosophy:

«Train consistently. Track intelligently. Progress visibly. Lock in.»

The application should prioritize functionality, speed, accuracy and excellent visual design over unnecessary features.

2. Target audience

Primary audience

People who regularly train at the gym and want to track their strength-training progress.

Typical users:

- Beginners who want structure and consistency.
- Intermediate lifters following workout splits.
- Experienced lifters who care about progressive overload.
- People working toward specific strength or physique goals.

User problems

Existing fitness applications often have one or more of these problems:

- Cluttered interfaces.
- Too many unnecessary features.
- Poor workout logging experiences.
- Complicated navigation.
- Weak exercise progression visualizations.
- Excessive advertisements or subscription restrictions.
- Poor offline functionality.
- Interfaces that feel outdated.

Lock-in should solve these problems with a fast, intuitive and visually polished experience.

3. Product principles

Every design and engineering decision should follow these principles.

3.1 Offline first

Users must be able to use the core application without an internet connection.

Workout data should be stored locally and must not depend on a server.

3.2 Fast workout logging

Logging a set should require as few interactions as reasonably possible.

The user should not have to navigate through multiple screens to record a weight and repetition count.

3.3 Progressive overload focused

The application should make it easy to answer:

- Am I getting stronger?
- Am I lifting more weight?
- Am I performing more repetitions?
- How has this exercise changed over time?
- What was my previous performance?

3.4 Premium visual experience

The interface should be modern, clean, minimal and visually consistent.

3.5 Data ownership

Workout records belong to the user.

The application should provide a way to export and back up data.

3.6 Simplicity

Do not introduce features just because other fitness applications have them.

Every feature should solve a real user problem.

4. Platform and technology

Initial technology stack

Layer| Technology
Mobile framework| Flutter
Language| Dart
State management| Riverpod
Local database| SQLite
Database abstraction| Drift
Navigation| GoRouter
Charts| Flutter-compatible charting library
Notifications| Flutter local notifications
Backend| Not required for MVP
Version control| Git and GitHub

These are initial recommendations. Review dependencies before introducing them, and avoid unnecessary packages.

Architecture

Use a feature-first architecture with clear separation between:

- Presentation layer
- Application/business logic
- Data layer
- Shared components and utilities

Suggested project structure:

lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│
├── core/
│   ├── constants/
│   ├── database/
│   ├── errors/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── dashboard/
│   ├── workout/
│   ├── exercises/
│   ├── routines/
│   ├── history/
│   ├── statistics/
│   ├── body_tracking/
│   └── settings/
│
└── main.dart

Each feature should contain its own relevant presentation, domain and data code as complexity grows.

Do not over-engineer the initial application.

5. Information architecture

The main navigation should use a bottom navigation bar.

Recommended sections:

1. Home
2. Workout
3. History
4. Progress
5. Profile

Each section should have a clear purpose.

Home

The home screen is the primary dashboard.

It should provide a quick overview of the user's fitness activity and a prominent way to start a workout.

Workout

Used to start, perform and log workouts.

History

Displays previously completed workouts.

Progress

Shows strength progression, workout statistics and body metrics.

Profile

Contains personal information, preferences, settings and data management.

6. Functional requirements

6.1 Home dashboard

Priority: P0 — MVP

The dashboard should give users an immediate understanding of their training activity.

Required components

A. Greeting and date

- Contextual greeting.
- Current date.
- Optional profile image or initials.

B. Start workout

A prominent button or card that allows users to:

- Start an empty workout.
- Select a saved routine.
- Resume an active workout, if one exists.

C. Weekly activity

Show:

- Number of workouts completed this week.
- Weekly training activity.
- Training consistency.
- A simple weekly activity visualization.

D. Recent workout

Display:

- Workout name.
- Date.
- Duration.
- Number of exercises.
- Total sets.

E. Personal records

Show recently achieved personal records when available.

F. Body weight

Display the latest recorded body weight and its change over time.

Acceptance criteria

- Dashboard loads without internet access.
- All information comes from locally stored records.
- Empty states are designed for new users.
- Starting a workout should be possible without navigating through multiple menus.

---

6.2 Workout tracking

Priority: P0 — Core functionality

This is the most important feature of Lock-in.

The workout logging experience must be fast, reliable and intuitive.

Starting a workout

Users should be able to:

- Start an empty workout.
- Start a workout using a saved routine.
- Give the workout a custom name.
- Add exercises while the workout is active.

Active workout screen

Display:

- Workout name.
- Elapsed duration.
- Exercise list.
- Sets completed.
- Workout completion progress.
- Add exercise action.
- Finish workout action.

Exercise logging

Each exercise should support:

- Exercise name.
- Set number.
- Weight.
- Repetitions.
- Set completion status.
- Optional notes.

For example:

Set| Weight| Reps| Status
1| 22.5 kg| 10| Completed
2| 22.5 kg| 8| Completed
3| 20 kg| 10| Pending

The user must be able to:

- Add sets.
- Remove sets.
- Edit weight.
- Edit repetitions.
- Mark sets as completed.
- Reorder exercises.
- Remove exercises.
- Add exercises during a workout.

Previous performance

When an exercise is added, show the user's previous performance for that exercise.

Example:

Incline Dumbbell Press

Previous workout:

- 22.5 kg × 10
- 22.5 kg × 8
- 20 kg × 10

This helps users understand what they need to beat.

Rest timer

Provide an optional rest timer.

Requirements:

- Start timer after completing a set.
- Allow manual start and stop.
- Allow duration adjustment.
- Display countdown prominently.
- Provide vibration or notification when the timer ends, subject to device permissions.
- Do not force users to use the timer.

Finishing a workout

When users finish a workout, save:

- Workout name.
- Start time.
- End time.
- Duration.
- Exercises.
- Sets.
- Repetitions.
- Weights.
- Notes.

Show a workout summary.

The user should be able to review the completed session.

Workout recovery

Important reliability requirements:

- An active workout must survive app restarts.
- Data must be saved as the user logs it, not only when the workout is completed.
- Accidental navigation away from the workout must not silently discard data.
- The user should be able to resume an interrupted workout.

Acceptance criteria

- Users can log a complete workout offline.
- Sets are persisted immediately.
- The app can recover an active workout after being closed.
- Previous performance is displayed correctly.
- Finishing a workout creates a persistent history record.
- No completed workout is silently overwritten.

---

6.3 Exercise library

Priority: P0 — MVP

Provide a searchable exercise library.

Exercise information

Each exercise should support:

- Exercise name.
- Primary muscle group.
- Secondary muscle groups.
- Equipment.
- Exercise category.
- Instructions or description.
- Optional demonstration image or animation.

Muscle groups

Initial muscle groups:

- Chest
- Back
- Shoulders
- Biceps
- Triceps
- Forearms
- Quadriceps
- Hamstrings
- Glutes
- Calves
- Abs
- Core

Equipment

Initial equipment categories:

- Dumbbells
- Barbells
- Cables
- Machines
- Bodyweight
- Resistance bands
- Other

Exercise library functionality

Users should be able to:

- Search exercises.
- Filter by muscle group.
- Filter by equipment.
- View exercise details.
- Add exercises to workouts.
- Create custom exercises.

Custom exercises

Users must be able to create their own exercises.

Custom exercises should support the same core fields as standard exercises.

Acceptance criteria

- Exercise search works locally.
- Users can create custom exercises.
- Exercises can be reused across different workouts.
- Deleting an exercise must not silently destroy historical workout records.

---

6.4 Workout routines

Priority: P1 — MVP extension

Allow users to create reusable workout templates.

Examples:

- Push Day
- Pull Day
- Leg Day
- Upper Body
- Lower Body
- Full Body

Requirements

Users should be able to:

- Create a routine.
- Name a routine.
- Add exercises.
- Reorder exercises.
- Set a suggested number of sets.
- Edit or delete routines.
- Start a workout from a routine.

A routine is a template, not a workout record.

Changes to a routine should not modify previously completed workouts.

---

6.5 Workout history

Priority: P0 — MVP

Display all completed workouts.

History list

Each entry should display:

- Workout name.
- Date.
- Duration.
- Number of exercises.
- Total completed sets.

Workout details

When a user opens a workout, display:

- All exercises.
- Sets, weights and repetitions.
- Exercise order.
- Duration.
- Notes.

Additional functionality

- Filter workouts by date.
- Search workouts by name.
- View workout details.
- Edit historical records.
- Delete workouts with confirmation.

Historical workout records should remain accessible even if an exercise is renamed or removed from the library.

---

6.6 Progress and statistics

Priority: P1 — MVP extension

This section should make training progress understandable.

Avoid overwhelming users with meaningless statistics.

A. Exercise progression

For every exercise, show:

- Historical weight progression.
- Repetition progression.
- Best performance.
- Most recent performance.
- Estimated one-rep max where appropriate.

Provide selectable time ranges:

- 1 month
- 3 months
- 6 months
- 1 year
- All time

B. Personal records

Track relevant records such as:

- Heaviest weight lifted.
- Most repetitions at a given weight.
- Best estimated one-rep max.

Records should be calculated consistently and should not confuse different exercise variations.

C. Training volume

Calculate training volume using:

"Volume = Sum(weight × repetitions)"

Show volume by:

- Workout.
- Week.
- Month.
- Exercise.
- Muscle group, where the data supports it.

Clearly document calculation rules, especially for bodyweight exercises.

D. Weekly training activity

Show:

- Number of workouts.
- Total training duration.
- Total sets.
- Training frequency.

E. Muscle group distribution

Provide a visual breakdown of training volume or completed sets across muscle groups.

Avoid implying that this is a direct measurement of muscle growth.

Acceptance criteria

- Statistics are calculated from saved workout data.
- Historical changes are reflected correctly.
- Empty states are supported.
- Charts remain readable on mobile screens.
- Users can switch time ranges.

---

6.7 Body tracking

Priority: P1 — MVP extension

Allow users to track physical changes independently of workout performance.

Measurements

Initial support:

- Body weight.
- Body fat percentage (optional manual entry).
- Waist.
- Chest.
- Left and right arms.
- Thighs.
- Hips.

Users should not be required to enter every measurement.

Requirements

- Add a measurement entry.
- Edit or delete entries.
- Record the date.
- View historical values.
- Show progress charts.
- Display the latest recorded measurement.

Body weight should be the simplest and most prominent measurement.

Do not attempt to estimate body fat from weight alone.

---

6.8 Profile and settings

Priority: P1

User profile should support:

- Name or display name.
- Profile image, optional.
- Height.
- Current body weight.
- Preferred weight unit.
- Preferred measurement unit.

Settings should include:

- Kilograms / pounds.
- Rest timer defaults.
- Notification preferences.
- Theme preferences.
- Data export.
- Data backup and restore.
- About page.
- App version.

The application should default to kilograms and centimetres.

---

7. UI/UX design requirements

7.1 Visual direction

The primary visual inspiration is Xiaomi Mi Fitness.

However, Lock-in should have its own visual identity.

The interface should feel:

- Premium.
- Minimal.
- Athletic.
- Modern.
- Clean.
- Data-focused.
- Responsive.

Avoid making the application look like a generic Material Design template.

7.2 Design language

Recommended initial direction:

Theme: Dark-first.

Background: Near-black or very dark charcoal.

Cards: Slightly elevated dark surfaces.

Accent: One distinctive accent colour used consistently.

Typography: Modern, highly readable sans-serif.

Numbers: Large, clear and visually prominent for weights, repetitions and statistics.

Corners: Rounded cards with consistent radius.

Spacing: Consistent spacing system.

Icons: Simple and consistent icon family.

Do not overuse gradients, shadows, borders or decorative effects.

7.3 Component design

Create reusable components for:

- Primary buttons.
- Secondary buttons.
- Workout cards.
- Exercise cards.
- Set logging rows.
- Progress cards.
- Statistic cards.
- Charts.
- Empty states.
- Bottom navigation.
- Dialogs and bottom sheets.
- Loading and error states.

The same component should look and behave consistently throughout the application.

7.4 Motion and interaction

Use subtle animations for:

- Completing a set.
- Starting a workout.
- Switching screens.
- Updating statistics.
- Completing a workout.

Animations should never delay important actions.

7.5 Responsive design

The initial target is Android phones.

Support:

- Small Android screens.
- Standard Android phones.
- Larger Android phones.
- Different display densities.
- System font scaling.
- Safe areas and gesture navigation.

The app should remain usable on different screen sizes.

---

8. Data model

Use a relational local database.

The following are conceptual entities. Adjust the implementation based on the chosen database architecture.

UserProfile

id
name
height
weight_unit
measurement_unit
created_at
updated_at

Exercise

id
name
primary_muscle_group
secondary_muscle_groups
equipment
description
is_custom
created_at
updated_at

Routine

id
name
description
created_at
updated_at

RoutineExercise

id
routine_id
exercise_id
position
suggested_sets

Workout

id
name
started_at
completed_at
duration_seconds
notes
status
created_at
updated_at

WorkoutExercise

id
workout_id
exercise_id
position
notes

WorkoutSet

id
workout_exercise_id
set_number
weight
repetitions
is_completed
created_at
updated_at

BodyMeasurement

id
measurement_type
value
unit
recorded_at
created_at
updated_at

Important data rules

- Use stable identifiers.
- Store timestamps consistently.
- Preserve historical workout information.
- Do not rely on exercise names as unique identifiers.
- Avoid destructive cascading deletes for historical workout data.
- Use database transactions where multiple related records must be updated together.
- Define how deleted exercises are represented in historical records.
- Store weights and measurements with adequate precision.
- Keep workout records independent of routine templates.

9. Non-functional requirements

Performance

- Dashboard should load quickly.
- Workout logging should feel instantaneous.
- Navigation should be smooth.
- Database operations should not block the UI.
- Charts should remain responsive with larger histories.

Reliability

- Persist workout data immediately.
- Recover active workouts after application restarts.
- Handle unexpected application termination.
- Protect against accidental data loss.
- Use appropriate database migrations.

Offline support

All MVP features must work without internet access.

Do not introduce mandatory authentication.

Privacy

- Keep personal fitness records on the device in the MVP.
- Do not collect unnecessary personal information.
- Do not send workout data to external services without explicit user consent.

Accessibility

- Provide adequate contrast.
- Use readable font sizes.
- Ensure touch targets are comfortable.
- Support system font scaling.
- Do not communicate state through colour alone.

10. MVP scope and release priorities

The project must be developed incrementally.

Phase 1 — Foundation

Goal: Establish the application architecture and visual identity.

Deliverables:

- Flutter project setup.
- Feature-first folder structure.
- Theme and design system.
- Navigation.
- Reusable UI components.
- Local database foundation.

Acceptance criteria:

- Application launches successfully.
- Navigation works.
- Theme is consistent.
- Architecture is understandable and maintainable.

Phase 2 — Dashboard and exercise library

Deliverables:

- Home dashboard.
- Exercise library.
- Exercise search.
- Muscle group filters.
- Custom exercise creation.

Acceptance criteria:

- Dashboard displays meaningful empty states.
- Exercises can be searched and viewed.
- Custom exercises can be created and persisted.

Phase 3 — Workout engine

Highest priority functional milestone.

Deliverables:

- Start workout.
- Add exercises.
- Log sets.
- Edit weights and repetitions.
- Complete sets.
- Rest timer.
- Previous performance.
- Finish workout.
- Active workout recovery.

Acceptance criteria:

- A complete workout can be recorded offline.
- Data survives app restarts.
- No workout data is lost when navigating away.
- Previous performance is correctly retrieved.

Phase 4 — History and routines

Deliverables:

- Workout history.
- Workout details.
- Routine creation.
- Routine editing.
- Start workout from routine.

Acceptance criteria:

- Completed workouts are accessible.
- Routines can be reused.
- Routine changes do not alter completed workouts.

Phase 5 — Statistics and body tracking

Deliverables:

- Exercise progression charts.
- Personal records.
- Training volume.
- Weekly activity.
- Muscle group distribution.
- Body weight tracking.
- Measurement history.

Acceptance criteria:

- Statistics are derived from actual workout records.
- Charts show accurate historical data.
- Body measurements persist locally.

Phase 6 — Polish and release preparation

Deliverables:

- UI refinement.
- Animations.
- Error handling.
- Database migration testing.
- Performance optimization.
- Data export and restore.
- Android release build.

11. Features explicitly outside the initial MVP

Do not implement these unless specifically requested later.

- Social feed.
- Following othe