(in-package :d2clone-kit)


(defsystem item
  ()
  (:documentation "Handles items."))

(defcomponent (item)
  (type nil :type keyword))

(defmethod make-component ((system item-system) entity &rest parameters)
  (destructuring-bind (&key type) parameters
    (make-item entity :type type)
    (make-component *sprite-system* entity
                    :prefab :loot
                    :layers-initially-toggled (list type))))

(defun draw-item-text (item-entity renderer)
  "Draws a text above an item for ITEM-ENTITY with RENDERER."
  (with-item item-entity ()
    (with-screen-coordinate item-entity (screen-x screen-y)
      (multiple-value-bind (x y)
          (absolute->viewport screen-x screen-y)
        (render
         renderer
         9000d0
         (let ((type type) (x x) (y y))
           #'(lambda ()
               ;; TODO : prevent text overlap
               (let* ((text (string-capitalize (substitute #\Space #\- (string type))))
                      (width (al:get-text-width (ui-font-large) text)))
                 (al:draw-filled-rectangle x y (+ x width) (+ y 20)
                                           (al:map-rgba 10 10 10 160))
                 (al:draw-text (ui-font-large)
                               (al:map-rgba 255 255 255 0) x y 0 text)))))))))

(define-constant +item-neighbours+ '((1 . 1)
                                     (1 . 0)
                                     (0 . 1)
                                     (1 . -1)
                                     (-1 . 1))
  :test #'equal)

(defun drop-item (owner-entity item)
  (flet ((entity-tile (entity)
           (with-coordinate entity ()
             (cons (round x) (round y)))))
    (let ((forbidden-positions '()))
      (with-items
          (push (entity-tile entity) forbidden-positions))
      (push (entity-tile (player-entity)) forbidden-positions)
      (with-coordinate owner-entity ()
        (let* ((owner-x (round x))
               (owner-y (round y))
               (positions
                 (mapcar
                  #'(lambda (delta)
                      (cons (+ owner-x (car delta))
                            (+ owner-y (cdr delta))))
                  +item-neighbours+)))
          (when-let (position
                     (some
                      #'(lambda (p)
                          (unless (or (find p forbidden-positions :test #'equal)
                                      (collidesp (car p) (cdr p)))
                            p))
                      positions))
            (make-object `((:coordinate :x ,(- (coerce (car position) 'double-float) 0.49d0)
                                        :y ,(- (coerce (cdr position) 'double-float) 0.49d0))
                           (:item :type ,item))
                         *session-entity*)))))))

  ;; TODO : unhardcode
(define-constant +weapons+
    '(:dagger (2d0 . 3d0)
      :short-sword (4d0 . 7d0)
      :long-sword (8d0 . 12d0)
      :great-sword (15d0 . 20d0))
  :test #'equal)

(defun pickup-item (item-entity)
  ;; TODO : unhardcode
  (with-item item-entity ()
    (if (eq type :health-potion)
        (let ((player-entity (player-entity)))
          (with-coordinate player-entity (player-x player-y)
            (make-object
             `((:coordinate :x ,player-x :y ,player-y)
               (:sound :prefab :gulp)) player-entity))
          (with-hp player-entity ()
            (set-hp player-entity (+ current-hp 20d0)))
          (delete-child *session-entity* item-entity)
          (delete-entity item-entity))
        (let ((player-entity (player-entity)))
          (with-sprite player-entity ()
            (doplist (weapon _ +weapons+)
              (when (gethash weapon layers-toggled)
                (drop-item player-entity weapon)
                (setf (gethash weapon layers-toggled) nil))))
          (toggle-layer player-entity type t)
          (with-combat player-entity ()
            (destructuring-bind (weapon-min-dmg . weapon-max-dmg)
                (getf +weapons+ type)
              (setf min-damage weapon-min-dmg
                    max-damage weapon-max-dmg)))
          (delete-child *session-entity* item-entity)
          (delete-entity item-entity)))))

(defhandler (item-system character-moved
             :filter (= (character-moved-entity event) (player-entity)))
  (with-coordinate (player-entity) (player-x player-y)
    (with-items
        (when (has-component-p :coordinate entity)
          (with-coordinate entity ()
            (when (and (approx-equal x player-x 0.49d0)
                       (approx-equal y player-y 0.49d0))
              (pickup-item entity)
              (return)))))))

(eval-when (:compile-toplevel :load-toplevel)
  ;; https://stackoverflow.com/a/29361029/1336774
  (defun biased-generator (values weights)
    (multiple-value-bind (total values)
        (loop :for v :in values
              :for w :in weights
              :nconc (make-list w :initial-element v) :into vs
              :sum w :into total
              :finally (return (values total (coerce vs 'vector))))
      #'(lambda ()
          (aref values (random total))))))

(define-constant +item-generator+
    ;; TODO : unhardcode
    (biased-generator '(nil :health-potion :dagger :short-sword :long-sword)
                      '(5 10 5 2 1))
  :test (constantly t))

(defhandler (item-system entity-died
             :filter (not (= (entity-died-entity event) (player-entity))))
  (when-let (item (funcall +item-generator+))
    (drop-item (entity-died-entity event) item)))
