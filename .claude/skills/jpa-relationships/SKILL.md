---
name: jpa-relationships
description: JPA entity relationships — OneToMany, ManyToOne, ManyToMany, cascade behaviour, equals/hashCode for entities, aggregate boundary rules. Use when modelling entity associations, deciding cascade behaviour, or implementing entity equality.
---

# JPA Relationships

Covers entity association mapping, cascade behaviour, and entity identity. For broader JPA context, see `.claude/skills/jpa-patterns/SKILL.md`. For aggregate boundary rules (when bidirectional relationships are valid), see `.claude/skills/domain-driven-design/SKILL.md`.

## When to Use
- Modelling a new entity relationship (`@OneToMany`, `@ManyToOne`, `@ManyToMany`)
- Deciding cascade behaviour
- Implementing `equals`/`hashCode` on entities
- Reviewing association mappings for aggregate boundary violations

---

## OneToMany / ManyToOne

> **Note on primary key type**: code examples use `Long` + `GenerationType.IDENTITY` for brevity. For high-write aggregates, prefer UUIDv7, ULID, or application-generated IDs over `IDENTITY`/`SEQUENCE` — they avoid ID generation round-trips and are safe for distributed environments. The chosen strategy must be justified in the spec.

> **Aggregate boundary rule**: bidirectional `@OneToMany`/`@ManyToOne` is only valid when both entities belong to the same aggregate. Across aggregate boundaries, hold a reference by ID only — never a direct entity reference or a bidirectional mapping. See `domain-driven-design` skill.

```java
// ✅ GOOD: Bidirectional with proper mapping — valid only within the same aggregate
@Entity
public class Author {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToMany(mappedBy = "author", cascade = {CascadeType.PERSIST, CascadeType.MERGE}, orphanRemoval = true)
    private List<Book> books = new ArrayList<>();

    // Use intention-revealing methods — never call setters from outside the entity
    public void addBook(Book book) {
        books.add(book);
        book.assignAuthor(this);
    }

    public void removeBook(Book book) {
        books.remove(book);
        book.clearAuthor();
    }
}

@Entity
public class Book {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id")
    private Author author;

    // Package-visible bidirectional sync — called only by Author helper methods
    void assignAuthor(Author author) { this.author = author; }
    void clearAuthor() { this.author = null; }
}
```

---

## ManyToMany

> **Aggregate boundary rule**: bidirectional `@ManyToMany` is only valid when both entities belong to the same aggregate. Across aggregate boundaries, hold a reference by ID only — never a direct entity reference or a bidirectional mapping.

```java
// ✅ GOOD: ManyToMany with Set (not List) to avoid duplicates — valid only within the same aggregate
@Entity
public class Student {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToMany(cascade = {CascadeType.PERSIST, CascadeType.MERGE})
    @JoinTable(
        name = "student_course",
        joinColumns = @JoinColumn(name = "student_id"),
        inverseJoinColumns = @JoinColumn(name = "course_id")
    )
    private Set<Course> courses = new HashSet<>();

    // Use intention-revealing methods — never mutate another entity's collection directly via getter
    public void addCourse(Course course) {
        courses.add(course);
        course.addStudent(this);
    }

    public void removeCourse(Course course) {
        courses.remove(course);
        course.removeStudent(this);
    }
}

@Entity
public class Course {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToMany(mappedBy = "courses")
    private Set<Student> students = new HashSet<>();

    // Package-visible bidirectional sync — called only by Student helper methods
    void addStudent(Student student) { students.add(student); }
    void removeStudent(Student student) { students.remove(student); }
}
```

---

## equals() and hashCode() for Entities

```java
// ✅ GOOD: Use business key or ID carefully
@Entity
public class Book {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NaturalId  // Hibernate annotation for business key
    @Column(unique = true, nullable = false)
    private String isbn;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof Book book)) return false;
        return isbn != null && isbn.equals(book.isbn);
    }

    @Override
    public int hashCode() {
        return Objects.hash(isbn);  // Use business key, not ID
    }
}
```

**Rules:**
- Use identifier equality once the entity is persisted; use a natural key only if it is immutable and guaranteed unique
- Never base `hashCode` on a mutable field — this breaks entity identity inside the persistence context and in collections

---

## Cascade Misuse

```java
// ❌ BAD: CascadeType.ALL — forbidden. Includes REMOVE and REFRESH;
// on @ManyToOne it can delete the parent; on @OneToMany it cascades removes beyond orphanRemoval.
@Entity
public class Book {
    @ManyToOne(cascade = CascadeType.ALL)  // Deleting a book could delete the author
    private Author author;
}

// ✅ GOOD: Explicit cascade — only what is intentional
@Entity
public class Author {
    @OneToMany(mappedBy = "author", cascade = {CascadeType.PERSIST, CascadeType.MERGE}, orphanRemoval = true)
    private List<Book> books;
}
```

**Cascade rules:**
- `CascadeType.ALL` is forbidden — declare each cascade explicitly per association
- Only cascade from parent to child (`@OneToMany`); never from child to parent (`@ManyToOne`)
- Every cascade declaration must be justified in a code comment

---

## Related Skills

- `jpa-patterns` — index of all JPA skills
- `domain-driven-design` — aggregate boundaries, why cross-aggregate references must be by ID only
- `jpa-fetching` — fetch strategies for relationships (LAZY default, JOIN FETCH, @EntityGraph)
