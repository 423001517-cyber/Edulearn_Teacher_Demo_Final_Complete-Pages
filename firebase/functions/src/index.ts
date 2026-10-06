/**
 * EduLearn Cloud Functions (region asia-southeast1, schedules in Asia/Manila).
 *
 *   onSubmissionWritten      classwork counters, missing-work cleanup, feed, notifications
 *   onClassworkWritten       class questCount, "new quiz published" feed entries
 *   onStudentWritten         class studentCount, "joined the class" feed entries
 *   onAnnouncementCreated    "You posted an announcement" feed entries
 *   deliverReminder          FCM push for "Send Reminder"
 *   publishScheduledClasswork hourly: scheduled → published on its date
 *   nightlyRollup            9 PM: progress, missing work, charts, report stats
 *
 * Class stream:
 *   publishScheduledPosts    every 5 min: scheduled posts go live
 *   onAnnouncementComment · onClassworkComment   comment counts + teacher notices
 *
 * Admin website (callable, caller must have the `admin` custom claim):
 *   createClass · approveClassRequest · declineClassRequest · regenerateClassCode
 *   createTeacherAccount · teacherPasswordLink · setTeacherStatus · setAdminRole
 *   onClassReassigned        moves a class's documents to its new teacher
 */
export { onAnnouncementCreated, onClassworkWritten, onStudentWritten, onSubmissionWritten } from './triggers';
export { deliverReminder } from './reminders';
export { nightlyRollup, publishScheduledClasswork } from './scheduled';
export {
  approveClassRequest,
  createClass,
  createTeacherAccount,
  declineClassRequest,
  regenerateClassCode,
  setAdminRole,
  setTeacherStatus,
  teacherPasswordLink,
} from './admin/callables';
export { onClassReassigned } from './admin/propagate';
export { onAnnouncementComment, onClassworkComment, publishScheduledPosts } from './stream/triggers';
