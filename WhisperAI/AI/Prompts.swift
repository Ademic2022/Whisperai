import Foundation

enum Prompts {
    static func system(role: String, company: String, type: String, resume: String) -> String {
        var prompt = """
        You are an expert interview coach and real-time assistant helping a candidate \
        during a live job interview. Your answers must be:
        - Concise and direct (2-4 sentences max unless asked for more)
        - Structured with **bold** for key points
        - Immediately actionable — the candidate reads your response live
        - Calibrated to the seniority of the role

        """

        if !role.isEmpty    { prompt += "Role: \(role)\n" }
        if !company.isEmpty { prompt += "Company: \(company)\n" }
        if !type.isEmpty    { prompt += "Interview type: \(type)\n" }

        if !resume.isEmpty {
            let excerpt = String(resume.prefix(6000))
            prompt += "\n---\nCANDIDATE RESUME:\n\(excerpt)\n---\n"
        }

        prompt += "\nRespond only to what was said. Do not add filler or preamble."
        return prompt
    }
}
