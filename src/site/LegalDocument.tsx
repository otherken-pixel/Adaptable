import { formatInline, type LegalDoc } from "./legal";
import MarketingLayout from "./MarketingLayout";

function Html({ text, className }: { text: string; className?: string }) {
  return (
    <span
      className={className}
      dangerouslySetInnerHTML={{ __html: formatInline(text) }}
    />
  );
}

export default function LegalDocument({ doc }: { doc: LegalDoc }) {
  return (
    <MarketingLayout title={doc.title}>
      <article className="site-doc mx-auto max-w-3xl px-5 pt-10 pb-16">
        {doc.updated ? (
          <p className="text-[11px] font-extrabold tracking-wider text-faint uppercase">
            Last updated: {doc.updated}
          </p>
        ) : null}
        <h1 className="mt-1 text-3xl font-extrabold tracking-tight sm:text-4xl">
          {doc.title}
        </h1>
        {doc.lede ? (
          <p className="mt-3 text-[15px] leading-relaxed text-muted">
            <Html text={doc.lede} />
          </p>
        ) : null}

        {doc.contact ? (
          <div className="mt-6 rounded-card border border-line bg-raised px-5 py-4">
            <a
              href={`mailto:${doc.contact.email}`}
              className="block text-xl font-extrabold break-all text-accent"
            >
              {doc.contact.email}
            </a>
            <p className="mt-1 text-sm text-muted">{doc.contact.note}</p>
          </div>
        ) : null}

        {doc.sections.map((section) => (
          <section key={section.heading} id={section.id} className="scroll-mt-20">
            <h2 className="mt-8 text-lg font-extrabold">{section.heading}</h2>
            {section.paragraphs?.map((p) => (
              <p key={p} className="mt-2 text-[15px] leading-relaxed text-muted">
                <Html text={p} />
              </p>
            ))}
            {section.bullets ? (
              <ul className="mt-2 list-disc space-y-1.5 pl-5 text-[15px] leading-relaxed text-muted">
                {section.bullets.map((item) => (
                  <li key={item}>
                    <Html text={item} />
                  </li>
                ))}
              </ul>
            ) : null}
            {section.after?.map((p) => (
              <p key={p} className="mt-2 text-[15px] leading-relaxed text-muted">
                <Html text={p} />
              </p>
            ))}
          </section>
        ))}
      </article>
    </MarketingLayout>
  );
}
