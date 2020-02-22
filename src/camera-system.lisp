(in-package :d2clone-kit)


(defclass camera-system (system)
  ((name :initform 'camera)
   (entity :initform nil))
  (:documentation "Handles camera entity."))

(defcomponent camera camera)

(defmethod system-load ((system camera-system))
  (declare (ignore system))
  t)

(defmethod system-quit ((system camera-system))
  (setf (slot-value system 'entity) -1)
  t)

(defmethod make-component ((system camera-system) entity &rest parameters)
  (declare (ignore parameters))
  (setf (slot-value system 'entity) entity)
  nil)

(declaim (inline camera-entity))
(defun camera-entity ()
  "Returns current camera entity."
  (slot-value (system-ref 'camera) 'entity))

(defmacro with-camera (bindings &body body)
  "Executes BODY with current camera position bound to two symbols in BIDNINGS list."
  (with-gensyms (camera-entity)
    `(let ((,camera-entity (camera-entity)))
       (with-coordinate ,camera-entity ,bindings
         ,@body))))

(declaim
 (inline absolute->viewport)
 ;; (ftype (function (coordinate coordinate) (values fixnum fixnum)) absolute->viewport)
 )
(defun absolute->viewport (x y)
  "Converts given integer absolute screen coordinates to viewport coordinates.

See VIEWPORT->ABSOLUTE"
  (with-system-config-options ((display-width display-height))
    (with-screen-coordinate (camera-entity)
        (camera-x camera-y)
      (values
       (+ (- x camera-x) (ceiling display-width 2))
       (+ (- y camera-y) (ceiling display-height 2))))))

(declaim
 (inline viewport->absolute)
 )
(defun viewport->absolute (x y)
  "Converts given integer viewport coordinates to absolute screen coordinates.

See ABSOLUTE->VIEWPORT"
  (with-system-config-options ((display-width display-height))
    (with-screen-coordinate (camera-entity)
        (camera-x camera-y)
      (values
       (+ x camera-x (- (ceiling display-width 2)))
       (+ y camera-y (- (ceiling display-height 2)))))))

(declaim
 (inline visiblep)
 (ftype (function (fixnum fixnum &optional fixnum) boolean) visiblep))
(defun visiblep (x y &optional (delta 0))
  "Returns T if point with given viewport coordinates is visible on screeen."
  (with-system-config-options ((display-width display-height))
    (and
     (and (> x (- delta))
          (< x (+ delta display-width)))
     (and (> y (- delta))
          (< y (+ delta display-height))))))

(declaim
 (inline range-visible-p)
 (ftype (function (fixnum fixnum fixnum fixnum) boolean) range-visible-p))
(defun range-visible-p (x y width height)
  "Returns T if any part of rectangular range defined by given viewport coordinates and dimensions is visible on screen."
  (with-system-config-options ((display-width display-height))
    (and
     (> x (- width))
     (< x display-width)
     (> y (- height))
     (< y display-height))))
