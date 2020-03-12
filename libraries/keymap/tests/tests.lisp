(in-package :cl-user)

(prove:plan nil)

(prove:subtest "Make key"
  (let* ((key (keymap:make-key :code 38 :value "a" :modifiers '("C")))
         (mod (first (fset:convert 'list (keymap:key-modifiers key)))))
    (prove:is (keymap:key-code key)
              38)
    (prove:is (keymap:key-value key)
              "a")
    (prove:is mod "C" :test #'keymap:modifier=)
    (prove:is mod "control" :test #'keymap:modifier=)
    (prove:is mod keymap:+control+ :test #'keymap:modifier=)
    (prove:isnt mod "" :test #'keymap:modifier=)
    (prove:isnt mod "M" :test #'keymap:modifier=)
    (prove:isnt mod "meta" :test #'keymap:modifier=)))

(prove:subtest "Make bad key"
  (prove:is-error (keymap:make-key :value "a" :status :dummy)
                  'type-error)
  (prove:is-error (keymap:make-key :value "a" :modifiers '("Z"))
                  'simple-error)
  (prove:is-error (keymap:make-key ::status :pressed)
                  'simple-error))

(prove:subtest "Make same key"
  (prove:is (keymap:make-key :value "a" :modifiers '("C" "M"))
            (keymap:make-key :value "a" :modifiers '("M" "C"))
            :test #'keymap::key=)
  (prove:is (keymap:make-key :value "a" :modifiers '("C"))
            (keymap:make-key :value "a" :modifiers '("control"))
            :test #'keymap::key=))

(prove:subtest "Make different key"
  (prove:isnt (keymap:make-key :value "a")
              (keymap:make-key :value "A")
              :test #'keymap::key=))

(prove:subtest "Keyspec->key"
  (prove:is (keymap::keyspec->key "a")
            (keymap:make-key :value "a")
            :test #'keymap::key=)
  (prove:is (keymap::keyspec->key "C-a")
            (keymap:make-key :value "a" :modifiers '("C"))
            :test #'keymap::key=)
  (prove:is (keymap::keyspec->key "C-M-a")
            (keymap:make-key :value "a" :modifiers '("C" "M"))
            :test #'keymap::key=)
  (prove:is (keymap::keyspec->key "C--")
            (keymap:make-key :value "-" :modifiers '("C"))
            :test #'keymap::key=)
  (prove:is (keymap::keyspec->key "C-M--")
            (keymap:make-key :value "-" :modifiers '("C" "M"))
            :test #'keymap::key=)
  (prove:is (keymap::keyspec->key "C-#")
            (keymap:make-key :value "#" :modifiers '("C"))
            :test #'keymap::key=)
  (prove:is (keymap::keyspec->key "#")
            (keymap:make-key :value "#")
            :test #'keymap::key=)
  (prove:is (keymap::keyspec->key "-")
            (keymap:make-key :value "-")
            :test #'keymap::key=)
  (prove:is (keymap::keyspec->key "C-#10")
            (keymap:make-key :code 10 :modifiers '("C"))
            :test #'keymap::key=)
  (prove:is-error (keymap::keyspec->key "C-")
                  'simple-error)
  (prove:is-error (keymap::keyspec->key "C---")
                  'simple-error))

(defun binding= (keys1 keys2)
  (not (position nil (mapcar #'keymap::key= keys1 keys2))))

(prove:subtest "Keyspecs->keys"
  (prove:is (keymap::keyspecs->keys "C-x C-f")
            (list (keymap:make-key :value "x" :modifiers '("C"))
                  (keymap:make-key :value "f" :modifiers '("C")))
            :test #'binding=)
  (prove:is (keymap::keyspecs->keys "  C-x   C-f  ")
            (list (keymap:make-key :value "x" :modifiers '("C"))
                  (keymap:make-key :value "f" :modifiers '("C")))
            :test #'binding=))

(prove:subtest "define-key & lookup-key"
  (let ((keymap (keymap:make-keymap)))
    (keymap:define-key keymap "C-x" 'foo)
    (prove:is (keymap:lookup-key keymap (keymap::keyspecs->keys "C-x"))
              'foo)
    (keymap:define-key keymap "C-x" 'foo2)
    (prove:is (keymap:lookup-key keymap (keymap::keyspecs->keys "C-x"))
              'foo2)
    (keymap:define-key keymap "C-c C-f" 'bar)
    (prove:is (keymap:lookup-key keymap (keymap::keyspecs->keys "C-c C-f"))
              'bar)
    (keymap:define-key keymap "C-c C-h" 'bar2)
    (prove:is (keymap:lookup-key keymap (keymap::keyspecs->keys "C-c C-h"))
              'bar2)))

(prove:subtest "define-key & lookup-key with parents"
  (let* ((parent1 (keymap:make-keymap))
         (parent2 (keymap:make-keymap))
         (keymap (keymap:make-keymap parent1 parent2)))
    (keymap:define-key parent1 "x" 'parent1-x)
    (keymap:define-key parent1 "a" 'parent1-a)
    (keymap:define-key parent2 "x" 'parent2-x)
    (keymap:define-key parent2 "b" 'parent2-b)
    (prove:is (keymap:lookup-key keymap (keymap::keyspecs->keys "x"))
              'parent1-x)
    (prove:is (keymap:lookup-key keymap (keymap::keyspecs->keys "a"))
              'parent1-a)
    (prove:is (keymap:lookup-key keymap (keymap::keyspecs->keys "b"))
              'parent2-b)))

(prove:subtest "define-key & lookup-key with prefix keymap"
  (let ((keymap (keymap:make-keymap))
        (prefix (keymap:make-keymap)))
    (keymap:define-key keymap "C-c" prefix)
    (keymap:define-key prefix "x" 'prefix-sym)
    (prove:is (keymap:lookup-key keymap (keymap::keyspecs->keys "C-c x"))
              'prefix-sym)))

(prove:subtest "define-key & lookup-key with cycle"
  (let ((keymap (keymap:make-keymap))
        (parent1 (keymap:make-keymap))
        (parent2 (keymap:make-keymap)))
    (push parent1 (keymap:parents keymap))
    (push parent2 (keymap:parents parent1))
    (push keymap (keymap:parents parent2))
    (prove:is (keymap:lookup-key keymap (keymap::keyspecs->keys "x"))
              nil)))

(prove:finalize)
